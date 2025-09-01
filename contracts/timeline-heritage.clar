;; Cultural Heritage Timeline System
;; Enables chronological organization of cultural artifacts and historical narratives

;; Error constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-exists (err u202))
(define-constant err-unauthorized (err u203))
(define-constant err-invalid-data (err u204))
(define-constant err-timeline-full (err u205))
(define-constant err-invalid-period (err u206))
(define-constant err-artifact-not-in-timeline (err u207))

;; Data variables for ID management
(define-data-var next-timeline-id uint u1)
(define-data-var contract-paused bool false)

;; Timeline definitions and metadata
(define-map cultural-timelines
    { timeline-id: uint }
    {
        title: (string-utf8 100),
        description: (string-utf8 300),
        creator: principal,
        category: (string-ascii 50),
        region: (string-utf8 100),
        created-at: uint,
        total-artifacts: uint,
        start-period: uint,
        end-period: uint,
        verified: bool,
        public-visible: bool
    }
)

;; Timeline entries linking artifacts with chronological data
(define-map timeline-entries
    { timeline-id: uint, artifact-id: uint }
    {
        historical-period: uint,
        sequence-order: uint,
        description-context: (string-utf8 200),
        added-by: principal,
        added-at: uint,
        verified: bool
    }
)

;; Track artifacts belonging to timelines
(define-map artifact-timeline-membership
    { artifact-id: uint }
    { timeline-id: uint, entry-exists: bool }
)

;; Timeline access permissions
(define-map timeline-permissions
    { timeline-id: uint, user: principal }
    { can-edit: bool, granted-by: principal, granted-at: uint }
)

;; Create a new cultural heritage timeline
(define-public (create-timeline
    (title (string-utf8 100))
    (description (string-utf8 300))
    (category (string-ascii 50))
    (region (string-utf8 100))
    (start-period uint)
    (end-period uint)
    (public-visible bool))
    (let
        ((timeline-id (var-get next-timeline-id))
         (current-block stacks-block-height))
        
        (asserts! (not (var-get contract-paused)) (err u106))
        (asserts! (> (len title) u0) err-invalid-data)
        (asserts! (> (len description) u0) err-invalid-data)
        (asserts! (> (len category) u0) err-invalid-data)
        (asserts! (< start-period end-period) err-invalid-period)
        
        (map-set cultural-timelines
            { timeline-id: timeline-id }
            {
                title: title,
                description: description,
                creator: tx-sender,
                category: category,
                region: region,
                created-at: current-block,
                total-artifacts: u0,
                start-period: start-period,
                end-period: end-period,
                verified: false,
                public-visible: public-visible
            }
        )
        
        (var-set next-timeline-id (+ timeline-id u1))
        (ok timeline-id)
    )
)

;; Add cultural artifact to timeline with chronological context
(define-public (add-artifact-to-timeline
    (timeline-id uint)
    (artifact-id uint)
    (historical-period uint)
    (sequence-order uint)
    (description-context (string-utf8 200)))
    (let
        ((timeline (unwrap! (map-get? cultural-timelines { timeline-id: timeline-id }) err-not-found))
         (current-block stacks-block-height)
         (existing-entry (map-get? timeline-entries { timeline-id: timeline-id, artifact-id: artifact-id })))
        
        (asserts! (not (var-get contract-paused)) (err u106))
        (asserts! (is-none existing-entry) err-already-exists)
        (asserts! (or (is-eq tx-sender (get creator timeline))
                     (is-eq tx-sender contract-owner)
                     (is-some (map-get? timeline-permissions { timeline-id: timeline-id, user: tx-sender })))
                 err-unauthorized)
        (asserts! (and (>= historical-period (get start-period timeline))
                      (<= historical-period (get end-period timeline))) err-invalid-period)
        (asserts! (< (get total-artifacts timeline) u50) err-timeline-full)
        
        ;; Add entry to timeline
        (map-set timeline-entries
            { timeline-id: timeline-id, artifact-id: artifact-id }
            {
                historical-period: historical-period,
                sequence-order: sequence-order,
                description-context: description-context,
                added-by: tx-sender,
                added-at: current-block,
                verified: false
            }
        )
        
        ;; Update timeline artifact count
        (map-set cultural-timelines
            { timeline-id: timeline-id }
            (merge timeline { total-artifacts: (+ (get total-artifacts timeline) u1) })
        )
        
        ;; Track artifact membership
        (map-set artifact-timeline-membership
            { artifact-id: artifact-id }
            { timeline-id: timeline-id, entry-exists: true }
        )
        
        (ok true)
    )
)

;; Remove artifact from timeline
(define-public (remove-artifact-from-timeline (timeline-id uint) (artifact-id uint))
    (let
        ((timeline (unwrap! (map-get? cultural-timelines { timeline-id: timeline-id }) err-not-found))
         (entry (unwrap! (map-get? timeline-entries { timeline-id: timeline-id, artifact-id: artifact-id }) err-not-found)))
        
        (asserts! (not (var-get contract-paused)) (err u106))
        (asserts! (or (is-eq tx-sender (get creator timeline))
                     (is-eq tx-sender (get added-by entry))
                     (is-eq tx-sender contract-owner)) err-unauthorized)
        
        ;; Remove timeline entry
        (map-delete timeline-entries { timeline-id: timeline-id, artifact-id: artifact-id })
        
        ;; Update timeline count
        (map-set cultural-timelines
            { timeline-id: timeline-id }
            (merge timeline { total-artifacts: (- (get total-artifacts timeline) u1) })
        )
        
        ;; Remove artifact membership
        (map-delete artifact-timeline-membership { artifact-id: artifact-id })
        
        (ok true)
    )
)

;; Grant timeline editing permissions
(define-public (grant-timeline-permission (timeline-id uint) (user principal))
    (let
        ((timeline (unwrap! (map-get? cultural-timelines { timeline-id: timeline-id }) err-not-found)))
        
        (asserts! (or (is-eq tx-sender (get creator timeline))
                     (is-eq tx-sender contract-owner)) err-unauthorized)
        
        (map-set timeline-permissions
            { timeline-id: timeline-id, user: user }
            {
                can-edit: true,
                granted-by: tx-sender,
                granted-at: stacks-block-height
            }
        )
        
        (ok true)
    )
)

;; Verify timeline (admin function)
(define-public (verify-timeline (timeline-id uint))
    (let
        ((timeline (unwrap! (map-get? cultural-timelines { timeline-id: timeline-id }) err-not-found)))
        
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get verified timeline)) err-already-exists)
        
        (map-set cultural-timelines
            { timeline-id: timeline-id }
            (merge timeline { verified: true })
        )
        
        (ok true)
    )
)

;; Update timeline entry context
(define-public (update-entry-context
    (timeline-id uint)
    (artifact-id uint)
    (new-context (string-utf8 200)))
    (let
        ((timeline (unwrap! (map-get? cultural-timelines { timeline-id: timeline-id }) err-not-found))
         (entry (unwrap! (map-get? timeline-entries { timeline-id: timeline-id, artifact-id: artifact-id }) err-not-found)))
        
        (asserts! (not (var-get contract-paused)) (err u106))
        (asserts! (or (is-eq tx-sender (get creator timeline))
                     (is-eq tx-sender (get added-by entry))
                     (is-eq tx-sender contract-owner)) err-unauthorized)
        
        (map-set timeline-entries
            { timeline-id: timeline-id, artifact-id: artifact-id }
            (merge entry { description-context: new-context })
        )
        
        (ok true)
    )
)

;; Read-only function to get timeline details
(define-read-only (get-timeline (timeline-id uint))
    (map-get? cultural-timelines { timeline-id: timeline-id })
)

;; Get timeline entry for specific artifact
(define-read-only (get-timeline-entry (timeline-id uint) (artifact-id uint))
    (map-get? timeline-entries { timeline-id: timeline-id, artifact-id: artifact-id })
)

;; Check if artifact belongs to a timeline
(define-read-only (get-artifact-timeline-info (artifact-id uint))
    (map-get? artifact-timeline-membership { artifact-id: artifact-id })
)

;; Get timeline permissions for user
(define-read-only (get-timeline-permissions (timeline-id uint) (user principal))
    (map-get? timeline-permissions { timeline-id: timeline-id, user: user })
)

;; Check if user can edit timeline
(define-read-only (can-edit-timeline (timeline-id uint) (user principal))
    (let
        ((timeline (map-get? cultural-timelines { timeline-id: timeline-id })))
        (if (is-some timeline)
            (let ((timeline-data (unwrap-panic timeline)))
                (or 
                    (is-eq user (get creator timeline-data))
                    (is-eq user contract-owner)
                    (is-some (map-get? timeline-permissions { timeline-id: timeline-id, user: user }))
                )
            )
            false
        )
    )
)

;; Get timeline statistics
(define-read-only (get-timeline-stats)
    {
        total-timelines: (- (var-get next-timeline-id) u1),
        contract-paused: (var-get contract-paused)
    }
)

;; Get artifacts in timeline ordered by period
(define-read-only (get-timeline-artifacts-summary (timeline-id uint))
    (let
        ((timeline (map-get? cultural-timelines { timeline-id: timeline-id })))
        (if (is-some timeline)
            (let ((timeline-data (unwrap-panic timeline)))
                (some {
                    title: (get title timeline-data),
                    total-artifacts: (get total-artifacts timeline-data),
                    start-period: (get start-period timeline-data),
                    end-period: (get end-period timeline-data),
                    verified: (get verified timeline-data),
                    public-visible: (get public-visible timeline-data)
                })
            )
            none
        )
    )
)
