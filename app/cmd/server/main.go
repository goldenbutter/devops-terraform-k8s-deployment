// Package main is the entry point for the devops-api server.
// It starts an HTTP server on port 8080 with graceful shutdown support,
// ensuring in-flight requests finish before the process exits.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/goldenbutter/devops-terraform-k8s-deployment/internal/handlers"
)

func main() {
	// Use a dedicated mux instead of the default so route registration
	// stays explicit and testable.
	mux := http.NewServeMux()
	handlers.RegisterRoutes(mux)

	// Read the listen port from the environment; default to 8080.
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 60 * time.Second, // CalcHandler can take several seconds under load.
		IdleTimeout:  120 * time.Second,
	}

	// Start the server in a goroutine so the main goroutine can listen
	// for OS signals and trigger a graceful shutdown.
	go func() {
		log.Printf("devops-api listening on :%s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	// Block until SIGINT or SIGTERM arrives (e.g. from Kubernetes sending
	// a TERM signal during pod termination).
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit
	log.Printf("received signal %s, shutting down gracefully…", sig)

	// Give in-flight requests up to 30 seconds to finish before forcing
	// a shutdown. This lines up with the default Kubernetes
	// terminationGracePeriodSeconds.
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("forced shutdown: %v", err)
	}
	log.Println("server stopped cleanly")
}
