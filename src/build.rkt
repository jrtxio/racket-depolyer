#lang racket

(provide check-tools
         install-dependencies
         build-site)

;; Check if Node.js and npm are available
(define (check-tools)
  (define node-ok? (system "which node > /dev/null 2>&1"))
  (define npm-ok? (system "which npm > /dev/null 2>&1"))
  
  (when (not node-ok?)
    (printf "✗ Node.js not found\n"))
  (when (not npm-ok?)
    (printf "✗ npm not found\n"))
  
  (and node-ok? npm-ok?))

;; Install dependencies using npm
;; Follows vercel.json installCommand
(define (install-dependencies repo-path)
  (printf "Installing dependencies...\n")
  (parameterize ([current-directory repo-path])
    (if (system "npm install")
        (begin
          (printf "✓ Dependencies installed\n")
          #t)
        (begin
          (printf "✗ Installation failed\n")
          #f))))

;; Build site using npm build command
;; Follows vercel.json buildCommand
(define (build-site repo-path)
  (printf "\n=== Building site ===\n")
  
  ;; Check if package.json exists
  (unless (file-exists? (build-path repo-path "package.json"))
    (error "package.json not found in ~a" repo-path))
  
  (define start (current-seconds))
  
  ;; Execute build command: npm run build
  ;; This automatically runs:
  ;; 1. prebuild: rimraf dist
  ;; 2. get-theme: node src/site/get-theme.js  
  ;; 3. build:sass: sass src/site/styles:dist/styles --style compressed
  ;; 4. build:eleventy: eleventy (with NODE_OPTIONS)
  (printf "Running: npm run build\n")
  (define build-ok?
    (parameterize ([current-directory repo-path])
      (system "npm run build")))
  
  (define duration (- (current-seconds) start))
  
  ;; Check output directory (from vercel.json outputDirectory)
  (define dist-path (build-path repo-path "dist"))
  
  (if (directory-exists? dist-path)
      (begin
        (printf "✓ Build completed in ~a seconds\n" duration)
        (printf "✓ Output directory: ~a\n" dist-path)
        (printf "===================\n\n")
        #t)
      (begin
        (printf "✗ Build failed - output directory not found\n")
        (printf "===================\n\n")
        #f)))