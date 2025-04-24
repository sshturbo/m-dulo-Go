package main

import (
	"context"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

const (
	baseScriptsFolder = "scripts"
	serverPort        = ":8040"
	requestTimeout    = 300 * time.Second
)

func main() {
	// Configuração do logger
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)

	// Inicializa o servidor
	for {
		startServer()
		log.Println("[ALERTA] Reiniciando servidor em 1 segundo...")
		time.Sleep(1 * time.Second)
	}
}

func startServer() {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[ERRO] O servidor falhou: %v. Reiniciando...\n", r)
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("/", serveIndex)
	mux.HandleFunc("/editar", routeHandler("editar", "editar.sh"))
	mux.HandleFunc("/deletar", routeHandler("deletar", "deletar.sh"))
	mux.HandleFunc("/criar", routeHandler("criar", ""))
	mux.HandleFunc("/online", routeHandler("online", ""))

	log.Printf("[INFO] Servidor iniciado em http://localhost%s\n", serverPort)

	// Inicia filas de execução
	go startQueues([]string{"editar", "deletar", "criar"})

	// Configuração do servidor com timeout
	server := &http.Server{
		Addr:         serverPort,
		Handler:      mux,
		ReadTimeout: 50 * time.Second,
		WriteTimeout: 50 * time.Second,
	}

	if err := server.ListenAndServe(); err != nil {
		log.Printf("[ERRO CRÍTICO] O servidor parou: %s\n", err)
		panic(err)
	}
}

func serveIndex(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "templates/index.html")
}

func routeHandler(routeName, expectedFilename string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
		defer cancel()

		r = r.WithContext(ctx)
		handleSpecificScript(w, r, routeName, expectedFilename)
	}
}

func handleSpecificScript(w http.ResponseWriter, r *http.Request, routeName, expectedFilename string) {
	if err := r.ParseMultipartForm(50 << 20); err != nil {
		http.Error(w, "Erro ao processar o formulário.", http.StatusBadRequest)
		return
	}

	file, handler, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Erro ao obter o arquivo.", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Validações do arquivo
	if expectedFilename != "" && handler.Filename != expectedFilename {
		http.Error(w, "Nome de arquivo inválido.", http.StatusBadRequest)
		return
	}
	if filepath.Ext(handler.Filename) != ".sh" {
		http.Error(w, "Apenas arquivos .sh são aceitos.", http.StatusBadRequest)
		return
	}

	folderPath := filepath.Join(baseScriptsFolder, routeName)
	if err := os.MkdirAll(folderPath, 0755); err != nil {
		http.Error(w, "Erro ao criar diretório.", http.StatusInternalServerError)
		return
	}

	filePath := filepath.Join(folderPath, handler.Filename)
	dst, err := os.Create(filePath)
	if err != nil {
		http.Error(w, "Erro ao criar arquivo.", http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		http.Error(w, "Erro ao salvar arquivo.", http.StatusInternalServerError)
		return
	}

	// Executa o script com timeout
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "bash", filePath)

	if err := cmd.Run(); err != nil {
		http.Error(w, "Erro ao executar o script.", http.StatusInternalServerError)
		return
	}

	os.Remove(filePath)
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("A sincronização foi iniciada com sucesso!"))
	log.Printf("[INFO] Script executado: %s\n", filePath)
}

func startQueues(routes []string) {
	for _, route := range routes {
		go func(route string) {
			folderPath := filepath.Join(baseScriptsFolder, route)
			_ = os.MkdirAll(folderPath, 0755)

			ticker := time.NewTicker(1 * time.Second)
			defer ticker.Stop()

			for range ticker.C {
				files, _ := filepath.Glob(filepath.Join(folderPath, "*.sh"))
				for _, file := range files {
					cmd := exec.Command("bash", file)
					if err := cmd.Run(); err != nil {
						log.Printf("[ERRO] Falha ao executar script %s: %s\n", file, err)
					} else {
						log.Printf("[INFO] Script executado: %s\n", file)
						os.Remove(file)
					}
				}
			}
		}(route)
	}
}
