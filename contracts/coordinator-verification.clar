;; Decentralized BI Self-Service Coordinator Verification Contract
;; Validates and manages BI self-service coordinators

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_COORDINATOR_NOT_FOUND (err u101))
(define-constant ERR_COORDINATOR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_CERTIFICATION (err u103))
(define-constant ERR_CERTIFICATION_EXPIRED (err u104))

;; Data Variables
(define-data-var next-coordinator-id uint u1)

;; Data Maps
(define-map coordinators
  { coordinator-id: uint }
  {
    address: principal,
    name: (string-ascii 50),
    certification-level: (string-ascii 20),
    certification-expiry: uint,
    verified-at: uint,
    is-active: bool,
    specializations: (list 5 (string-ascii 30))
  }
)

(define-map coordinator-by-address
  { address: principal }
  { coordinator-id: uint }
)

(define-map verification-history
  { coordinator-id: uint, verification-id: uint }
  {
    verified-by: principal,
    verification-date: uint,
    verification-type: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

;; Private Functions
(define-private (is-certification-valid (expiry uint))
  (> expiry block-height)
)

;; Public Functions
(define-public (register-coordinator
  (name (string-ascii 50))
  (certification-level (string-ascii 20))
  (certification-expiry uint)
  (specializations (list 5 (string-ascii 30))))
  (let ((coordinator-id (var-get next-coordinator-id)))
    (asserts! (is-none (map-get? coordinator-by-address { address: tx-sender })) ERR_COORDINATOR_ALREADY_EXISTS)
    (asserts! (is-certification-valid certification-expiry) ERR_INVALID_CERTIFICATION)

    (map-set coordinators
      { coordinator-id: coordinator-id }
      {
        address: tx-sender,
        name: name,
        certification-level: certification-level,
        certification-expiry: certification-expiry,
        verified-at: block-height,
        is-active: true,
        specializations: specializations
      }
    )

    (map-set coordinator-by-address
      { address: tx-sender }
      { coordinator-id: coordinator-id }
    )

    (var-set next-coordinator-id (+ coordinator-id u1))
    (ok coordinator-id)
  )
)

(define-public (verify-coordinator (coordinator-id uint) (verification-type (string-ascii 20)) (notes (string-ascii 200)))
  (let ((coordinator (unwrap! (map-get? coordinators { coordinator-id: coordinator-id }) ERR_COORDINATOR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set verification-history
      { coordinator-id: coordinator-id, verification-id: block-height }
      {
        verified-by: tx-sender,
        verification-date: block-height,
        verification-type: verification-type,
        notes: notes
      }
    )
    (ok true)
  )
)

(define-public (update-certification (coordinator-id uint) (new-expiry uint))
  (let ((coordinator (unwrap! (map-get? coordinators { coordinator-id: coordinator-id }) ERR_COORDINATOR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get address coordinator)) ERR_UNAUTHORIZED)
    (asserts! (is-certification-valid new-expiry) ERR_INVALID_CERTIFICATION)

    (map-set coordinators
      { coordinator-id: coordinator-id }
      (merge coordinator { certification-expiry: new-expiry })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-coordinator (coordinator-id uint))
  (map-get? coordinators { coordinator-id: coordinator-id })
)

(define-read-only (get-coordinator-by-address (address principal))
  (match (map-get? coordinator-by-address { address: address })
    coordinator-info (map-get? coordinators { coordinator-id: (get coordinator-id coordinator-info) })
    none
  )
)

(define-read-only (is-coordinator-active (coordinator-id uint))
  (match (map-get? coordinators { coordinator-id: coordinator-id })
    coordinator (and
      (get is-active coordinator)
      (is-certification-valid (get certification-expiry coordinator))
    )
    false
  )
)
