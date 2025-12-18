#lang racket

(require "config.rkt")

(provide check-deploy-config
         deploy-to-remote)

;; Check if rsync is available
(define (check-rsync)
  (system "which rsync > /dev/null 2>&1"))

;; Check if SSH key exists
(define (check-ssh-key ssh-key-path)
  (and ssh-key-path
       (file-exists? ssh-key-path)))

;; Validate deploy configuration
(define (check-deploy-config)
  (cond
    [(not (cfg-deploy-enabled?))
     (printf "✓ Deploy: Disabled\n")
     #t]
    [(not (check-rsync))
     (printf "✗ rsync not found. Install with: apt install rsync\n")
     #f]
    [(not (cfg-deploy-remote-host))
     (printf "✗ remote-host not configured\n")
     #f]
    [(not (cfg-deploy-remote-path))
     (printf "✗ remote-path not configured\n")
     #f]
    [(not (check-ssh-key (cfg-deploy-ssh-key)))
     (printf "✗ SSH key not found: ~a\n" (cfg-deploy-ssh-key))
     #f]
    [else
     (printf "✓ Deploy: Enabled → ~a:~a\n" 
             (cfg-deploy-remote-host)
             (cfg-deploy-remote-path))
     #t]))

;; Deploy built site to remote server using rsync
(define (deploy-to-remote)
  (if (not (cfg-deploy-enabled?))
      (begin
        (printf "Deploy disabled, skipping...\n")
        #t)
      (let* ([local-path (cfg-build-output)]
             [remote-host (cfg-deploy-remote-host)]
             [remote-path (cfg-deploy-remote-path)]
             [ssh-key (cfg-deploy-ssh-key)]
             [rsync-opts (cfg-deploy-rsync-options)]
             ;; Ensure local path ends with /
             [source (if (string-suffix? local-path "/")
                         local-path
                         (string-append local-path "/"))]
             ;; Build rsync command
             [rsync-cmd (format "rsync ~a -e 'ssh -i ~a -o StrictHostKeyChecking=no' ~a ~a:~a"
                               rsync-opts
                               ssh-key
                               source
                               remote-host
                               remote-path)])
        
        (printf "\n=== Deploying to remote ===\n")
        (printf "Command: ~a\n" rsync-cmd)
        (printf "Syncing files...\n")
        
        (let* ([start (current-seconds)]
               [result (system rsync-cmd)]
               [duration (- (current-seconds) start)])
          
          (if result
              (begin
                (printf "✓ Deploy completed in ~a seconds\n" duration)
                (printf "✓ Files synced to ~a:~a\n" remote-host remote-path)
                (printf "===========================\n\n")
                #t)
              (begin
                (printf "✗ Deploy failed\n")
                (printf "===========================\n\n")
                #f))))))