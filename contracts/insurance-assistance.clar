;; Insurance Assistance Contract
;; Helps residents navigate claims and coverage issues

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-INPUT (err u301))
(define-constant ERR-ALREADY-EXISTS (err u302))
(define-constant ERR-NOT-FOUND (err u303))
(define-constant ERR-INSUFFICIENT-BALANCE (err u304))

;; Data Variables
(define-data-var next-request-id uint u1)
(define-data-var next-helper-id uint u1)
(define-data-var total-requests uint u0)
(define-data-var total-helpers uint u0)

;; Token Definition
(define-fungible-token assist-token)

;; Data Maps
(define-map assistance-requests
  { request-id: uint }
  {
    requester: principal,
    description: (string-ascii 500),
    insurance-type: (string-ascii 50),
    status: (string-ascii 20),
    helper-assigned: (optional principal),
    timestamp: uint,
    completed: bool
  }
)

(define-map insurance-helpers
  { helper-id: uint }
  {
    name: (string-ascii 100),
    expertise: (string-ascii 200),
    contact: principal,
    active: bool,
    cases-completed: uint,
    rating: uint,
    tokens-earned: uint
  }
)

(define-map help-sessions
  { request-id: uint, helper: principal }
  {
    start-time: uint,
    end-time: (optional uint),
    notes: (string-ascii 500),
    tokens-awarded: uint,
    rating-given: uint
  }
)

(define-map user-helper-id
  { user: principal }
  { helper-id: uint }
)

;; Private Functions
(define-private (is-valid-insurance-type (insurance-type (string-ascii 50)))
  (or
    (is-eq insurance-type "home-insurance")
    (or
      (is-eq insurance-type "auto-insurance")
      (or
        (is-eq insurance-type "flood-insurance")
        (is-eq insurance-type "business-insurance")
      )
    )
  )
)

(define-private (calculate-help-tokens (session-duration uint))
  (if (< session-duration u60)
    u20
    (if (< session-duration u120)
      u40
      u60
    )
  )
)

;; Public Functions
(define-public (request-assistance (description (string-ascii 500)) (insurance-type (string-ascii 50)))
  (let
    (
      (request-id (var-get next-request-id))
    )
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-insurance-type insurance-type) ERR-INVALID-INPUT)

    ;; Store request
    (map-set assistance-requests
      { request-id: request-id }
      {
        requester: tx-sender,
        description: description,
        insurance-type: insurance-type,
        status: "pending",
        helper-assigned: none,
        timestamp: block-height,
        completed: false
      }
    )

    ;; Update counters
    (var-set next-request-id (+ request-id u1))
    (var-set total-requests (+ (var-get total-requests) u1))

    (ok request-id)
  )
)

(define-public (register-helper (name (string-ascii 100)) (expertise (string-ascii 200)))
  (let
    (
      (helper-id (var-get next-helper-id))
    )
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? user-helper-id { user: tx-sender })) ERR-ALREADY-EXISTS)

    ;; Store helper
    (map-set insurance-helpers
      { helper-id: helper-id }
      {
        name: name,
        expertise: expertise,
        contact: tx-sender,
        active: true,
        cases-completed: u0,
        rating: u5,
        tokens-earned: u0
      }
    )

    ;; Map user to helper ID
    (map-set user-helper-id
      { user: tx-sender }
      { helper-id: helper-id }
    )

    ;; Update counters
    (var-set next-helper-id (+ helper-id u1))
    (var-set total-helpers (+ (var-get total-helpers) u1))

    (ok helper-id)
  )
)

(define-public (assign-helper (request-id uint) (helper principal))
  (let
    (
      (request (unwrap! (map-get? assistance-requests { request-id: request-id }) ERR-NOT-FOUND))
      (helper-data (unwrap! (map-get? user-helper-id { user: helper }) ERR-NOT-FOUND))
      (helper-info (unwrap! (map-get? insurance-helpers { helper-id: (get helper-id helper-data) }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "pending") ERR-INVALID-INPUT)
    (asserts! (get active helper-info) ERR-INVALID-INPUT)

    ;; Update request with assigned helper
    (map-set assistance-requests
      { request-id: request-id }
      (merge request {
        status: "assigned",
        helper-assigned: (some helper)
      })
    )

    ;; Create help session
    (map-set help-sessions
      { request-id: request-id, helper: helper }
      {
        start-time: block-height,
        end-time: none,
        notes: "",
        tokens-awarded: u0,
        rating-given: u0
      }
    )

    (ok true)
  )
)

(define-public (complete-session (request-id uint) (notes (string-ascii 500)) (rating uint))
  (let
    (
      (request (unwrap! (map-get? assistance-requests { request-id: request-id }) ERR-NOT-FOUND))
      (session (unwrap! (map-get? help-sessions { request-id: request-id, helper: tx-sender }) ERR-NOT-FOUND))
      (helper-data (unwrap! (map-get? user-helper-id { user: tx-sender }) ERR-NOT-FOUND))
      (helper (unwrap! (map-get? insurance-helpers { helper-id: (get helper-id helper-data) }) ERR-NOT-FOUND))
      (session-duration (- block-height (get start-time session)))
      (token-reward (calculate-help-tokens session-duration))
    )
    (asserts! (is-eq (some tx-sender) (get helper-assigned request)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (get end-time session)) ERR-ALREADY-EXISTS)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-INPUT)

    ;; Update session
    (map-set help-sessions
      { request-id: request-id, helper: tx-sender }
      (merge session {
        end-time: (some block-height),
        notes: notes,
        tokens-awarded: token-reward,
        rating-given: rating
      })
    )

    ;; Update request as completed
    (map-set assistance-requests
      { request-id: request-id }
      (merge request {
        status: "completed",
        completed: true
      })
    )

    ;; Update helper stats
    (map-set insurance-helpers
      { helper-id: (get helper-id helper-data) }
      (merge helper {
        cases-completed: (+ (get cases-completed helper) u1),
        tokens-earned: (+ (get tokens-earned helper) token-reward)
      })
    )

    ;; Mint tokens to helper
    (try! (ft-mint? assist-token token-reward tx-sender))

    (ok true)
  )
)

(define-public (transfer-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (ft-transfer? assist-token amount tx-sender recipient)
  )
)

;; Read-only Functions
(define-read-only (get-request (request-id uint))
  (map-get? assistance-requests { request-id: request-id })
)

(define-read-only (get-helper (helper-id uint))
  (map-get? insurance-helpers { helper-id: helper-id })
)

(define-read-only (get-session (request-id uint) (helper principal))
  (map-get? help-sessions { request-id: request-id, helper: helper })
)

(define-read-only (get-user-helper-id (user principal))
  (map-get? user-helper-id { user: user })
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance assist-token user)
)

(define-read-only (get-total-supply)
  (ft-get-supply assist-token)
)

(define-read-only (get-contract-stats)
  {
    total-requests: (var-get total-requests),
    total-helpers: (var-get total-helpers),
    next-request-id: (var-get next-request-id),
    next-helper-id: (var-get next-helper-id)
  }
)
