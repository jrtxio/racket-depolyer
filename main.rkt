#lang racket

(require web-server/servlet-env
         web-server/servlet
         web-server/http
         web-server/http/response
         "src/config.rkt"
         "src/webhook.rkt"
         "src/build.rkt"
         "src/deploy.rkt")

;; Main program
(define (main)
  ;; Load configuration
  (load-config)
  
  ;; Check build tools at startup
  (unless (check-tools)
    (error "Build tools not available. Please install Node.js and npm."))
  
  ;; Display startup information
  (printf "\n")
  (printf "========================================\n")
  (printf "  Blog Deploy Webhook Server\n")
  (printf "========================================\n")
  (printf "Port: ~a\n" (cfg-port))
  (printf "Listen: ~a\n" (cfg-listen-ip))
  (printf "Repo: ~a\n" (cfg-repo-path))
  
  ;; Check and display deploy configuration
  (check-deploy-config)
  
  (printf "========================================\n")
  (printf "\n")
  
  ;; Define servlet handler with error handling
  (define servlet-handler
    (lambda (req)
      (with-handlers ([exn:fail:network?
                       (lambda (e)
                         (printf "Network error: ~a\n" (exn-message e))
                         (response/output #:code 500 
                           (lambda (out) 
                             (fprintf out "Internal Server Error\n"))))]
                      [exn:fail?
                       (lambda (e)
                         (unless (string-contains? (exn-message e) "output port is closed")
                           (printf "Error: ~a\n" (exn-message e)))
                         (with-handlers ([exn:fail? void])
                           (response/output #:code 500 
                             (lambda (out) 
                               (fprintf out "Internal Server Error\n")))))])
        (handle-webhook req))))
  
  ;; Start HTTP server
  (define listen-ip (cfg-listen-ip))
  (printf "Starting HTTP server on ~a:~a...\n" listen-ip (cfg-port))
  
  ;; Display access information based on listen IP
  (cond
    [(string=? listen-ip "0.0.0.0")
     (printf "Server accessible from: http://YOUR_SERVER_IP:~a\n" (cfg-port))
     (printf "⚠ WARNING: Server is exposed to public network\n")
     (printf "⚠ GitHub webhook should use: http://YOUR_DOMAIN:~a/\n" (cfg-port))
     (printf "⚠ SSL verification must be DISABLED (not secure)\n")]
    [(string=? listen-ip "127.0.0.1")
     (printf "Server accessible from: http://localhost:~a (local only)\n" (cfg-port))
     (printf "Use Nginx as reverse proxy for public HTTPS access\n")]
    [else
     (printf "Server accessible from: http://~a:~a\n" listen-ip (cfg-port))])
  
  (printf "\n")
  
  (serve/servlet servlet-handler
                 #:port (cfg-port)
                 #:listen-ip listen-ip
                 #:servlet-path "/"
                 #:servlet-regexp #rx""
                 #:launch-browser? #f))

;; Run
(module+ main
  (main))