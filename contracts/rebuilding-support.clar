;; Rebuilding Support Contract
;; Facilitates construction coordination and contractor vetting

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-ALREADY-EXISTS (err u502))
(define-constant ERR-NOT-FOUND (err u503))
(define-constant ERR-INSUFFICIENT-BALANCE (err u504))

;; Data Variables
(define-data-var next-project-id uint u1)
(define-data-var next-contractor-id uint u1)
(define-data-var total-projects uint u0)
(define-data-var total-contractors uint u0)

;; Token Definition
(define-fungible-token rebuild-token)

;; Data Maps
(define-map rebuilding-projects
  { project-id: uint }
  {
    owner: principal,
    address: (string-ascii 100),
    project-type: (string-ascii 50),
    description: (string-ascii 500),
    estimated-cost: uint,
    status: (string-ascii 20),
    contractor-assigned: (optional principal),
    start-date: (optional uint),
    completion-date: (optional uint),
    tokens-distributed: uint
  }
)

(define-map contractors
  { contractor-id: uint }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialties: (string-ascii 200),
    contact: principal,
    verified: bool,
    projects-completed: uint,
    average-rating: uint,
    tokens-earned: uint
  }
)

(define-map project-assignments
  { project-id: uint, contractor: principal }
  {
    bid-amount: uint,
    timeline: uint,
    materials-cost: uint,
    labor-cost: uint,
    accepted: bool,
    completed: bool,
    final-rating: uint
  }
)

(define-map user-contractor-id
  { user: principal }
  { contractor-id: uint }
)

;; Private Functions
(define-private (is-valid-project-type (project-type (string-ascii 50)))
  (or
    (is-eq project-type "roof-repair")
    (or
      (is-eq project-type "foundation-repair")
      (or
        (is-eq project-type "full-rebuild")
        (or
          (is-eq project-type "water-damage")
          (is-eq project-type "electrical-repair")
        )
      )
    )
  )
)

(define-private (calculate-project-tokens (cost uint) (rating uint))
  (let
    (
      (base-tokens (/ cost u100))
      (rating-multiplier (if (>= rating u4) u2 u1))
    )
    (* base-tokens rating-multiplier)
  )
)

;; Public Functions
(define-public (create-project (address (string-ascii 100)) (project-type (string-ascii 50)) (description (string-ascii 500)) (estimated-cost uint))
  (let
    (
      (project-id (var-get next-project-id))
    )
    (asserts! (> (len address) u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-project-type project-type) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> estimated-cost u0) ERR-INVALID-INPUT)

    ;; Store project
    (map-set rebuilding-projects
      { project-id: project-id }
      {
        owner: tx-sender,
        address: address,
        project-type: project-type,
        description: description,
        estimated-cost: estimated-cost,
        status: "planning",
        contractor-assigned: none,
        start-date: none,
        completion-date: none,
        tokens-distributed: u0
      }
    )

    ;; Update counters
    (var-set next-project-id (+ project-id u1))
    (var-set total-projects (+ (var-get total-projects) u1))

    (ok project-id)
  )
)

(define-public (register-contractor (name (string-ascii 100)) (license-number (string-ascii 50)) (specialties (string-ascii 200)))
  (let
    (
      (contractor-id (var-get next-contractor-id))
    )
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len license-number) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? user-contractor-id { user: tx-sender })) ERR-ALREADY-EXISTS)

    ;; Store contractor
    (map-set contractors
      { contractor-id: contractor-id }
      {
        name: name,
        license-number: license-number,
        specialties: specialties,
        contact: tx-sender,
        verified: false,
        projects-completed: u0,
        average-rating: u0,
        tokens-earned: u0
      }
    )

    ;; Map user to contractor ID
    (map-set user-contractor-id
      { user: tx-sender }
      { contractor-id: contractor-id }
    )

    ;; Update counters
    (var-set next-contractor-id (+ contractor-id u1))
    (var-set total-contractors (+ (var-get total-contractors) u1))

    (ok contractor-id)
  )
)

(define-public (verify-contractor (contractor-id uint))
  (let
    (
      (contractor (unwrap! (map-get? contractors { contractor-id: contractor-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (get verified contractor)) ERR-ALREADY-EXISTS)

    ;; Update contractor as verified
    (map-set contractors
      { contractor-id: contractor-id }
      (merge contractor { verified: true })
    )

    (ok true)
  )
)

(define-public (submit-bid (project-id uint) (bid-amount uint) (timeline uint) (materials-cost uint) (labor-cost uint))
  (let
    (
      (project (unwrap! (map-get? rebuilding-projects { project-id: project-id }) ERR-NOT-FOUND))
      (contractor-data (unwrap! (map-get? user-contractor-id { user: tx-sender }) ERR-NOT-FOUND))
      (contractor (unwrap! (map-get? contractors { contractor-id: (get contractor-id contractor-data) }) ERR-NOT-FOUND))
    )
    (asserts! (get verified contractor) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project) "planning") ERR-INVALID-INPUT)
    (asserts! (> bid-amount u0) ERR-INVALID-INPUT)
    (asserts! (> timeline u0) ERR-INVALID-INPUT)

    ;; Store bid
    (map-set project-assignments
      { project-id: project-id, contractor: tx-sender }
      {
        bid-amount: bid-amount,
        timeline: timeline,
        materials-cost: materials-cost,
        labor-cost: labor-cost,
        accepted: false,
        completed: false,
        final-rating: u0
      }
    )

    (ok true)
  )
)

(define-public (accept-bid (project-id uint) (contractor principal))
  (let
    (
      (project (unwrap! (map-get? rebuilding-projects { project-id: project-id }) ERR-NOT-FOUND))
      (assignment (unwrap! (map-get? project-assignments { project-id: project-id, contractor: contractor }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner project)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project) "planning") ERR-INVALID-INPUT)

    ;; Update assignment
    (map-set project-assignments
      { project-id: project-id, contractor: contractor }
      (merge assignment { accepted: true })
    )

    ;; Update project
    (map-set rebuilding-projects
      { project-id: project-id }
      (merge project {
        status: "in-progress",
        contractor-assigned: (some contractor),
        start-date: (some block-height)
      })
    )

    (ok true)
  )
)

(define-public (complete-project (project-id uint) (final-rating uint))
  (let
    (
      (project (unwrap! (map-get? rebuilding-projects { project-id: project-id }) ERR-NOT-FOUND))
      (contractor (unwrap! (get contractor-assigned project) ERR-NOT-FOUND))
      (assignment (unwrap! (map-get? project-assignments { project-id: project-id, contractor: contractor }) ERR-NOT-FOUND))
      (contractor-data (unwrap! (map-get? user-contractor-id { user: contractor }) ERR-NOT-FOUND))
      (contractor-info (unwrap! (map-get? contractors { contractor-id: (get contractor-id contractor-data) }) ERR-NOT-FOUND))
      (token-reward (calculate-project-tokens (get bid-amount assignment) final-rating))
    )
    (asserts! (is-eq tx-sender (get owner project)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project) "in-progress") ERR-INVALID-INPUT)
    (asserts! (and (>= final-rating u1) (<= final-rating u5)) ERR-INVALID-INPUT)

    ;; Update assignment
    (map-set project-assignments
      { project-id: project-id, contractor: contractor }
      (merge assignment {
        completed: true,
        final-rating: final-rating
      })
    )

    ;; Update project
    (map-set rebuilding-projects
      { project-id: project-id }
      (merge project {
        status: "completed",
        completion-date: (some block-height),
        tokens-distributed: token-reward
      })
    )

    ;; Update contractor stats
    (let
      (
        (new-project-count (+ (get projects-completed contractor-info) u1))
        (current-total-rating (* (get average-rating contractor-info) (get projects-completed contractor-info)))
        (new-average-rating (/ (+ current-total-rating final-rating) new-project-count))
      )
      (map-set contractors
        { contractor-id: (get contractor-id contractor-data) }
        (merge contractor-info {
          projects-completed: new-project-count,
          average-rating: new-average-rating,
          tokens-earned: (+ (get tokens-earned contractor-info) token-reward)
        })
      )
    )

    ;; Mint tokens to contractor
    (try! (ft-mint? rebuild-token token-reward contractor))

    (ok true)
  )
)

(define-public (transfer-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (ft-transfer? rebuild-token amount tx-sender recipient)
  )
)

;; Read-only Functions
(define-read-only (get-project (project-id uint))
  (map-get? rebuilding-projects { project-id: project-id })
)

(define-read-only (get-contractor (contractor-id uint))
  (map-get? contractors { contractor-id: contractor-id })
)

(define-read-only (get-assignment (project-id uint) (contractor principal))
  (map-get? project-assignments { project-id: project-id, contractor: contractor })
)

(define-read-only (get-user-contractor-id (user principal))
  (map-get? user-contractor-id { user: user })
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance rebuild-token user)
)

(define-read-only (get-total-supply)
  (ft-get-supply rebuild-token)
)

(define-read-only (get-contract-stats)
  {
    total-projects: (var-get total-projects),
    total-contractors: (var-get total-contractors),
    next-project-id: (var-get next-project-id),
    next-contractor-id: (var-get next-contractor-id)
  }
)
