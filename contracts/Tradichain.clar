(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-data (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-category (err u105))
(define-constant err-insufficient-payment (err u107))
(define-constant err-not-for-sale (err u108))
(define-constant err-invalid-price (err u109))
(define-constant err-cannot-buy-own-artifact (err u110))
(define-constant err-transfer-failed (err u111))

(define-data-var next-artifact-id uint u1)
(define-data-var next-curator-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var next-listing-id uint u1)
(define-data-var marketplace-fee-rate uint u250)

(define-map artifacts
  { artifact-id: uint }
  {
    title: (string-ascii 100),
    description: (string-utf8 500),
    content-hash: (string-ascii 64),
    category: (string-ascii 50),
    origin-location: (string-utf8 100),
    creator: principal,
    curator: principal,
    timestamp: uint,
    block-height: uint,
    verified: bool,
    vote-count: uint,
    access-level: uint,
    for-sale: bool,
    sale-price: uint,
    owner: principal
  }
)

(define-map curators
  { curator-id: uint }
  {
    curator-address: principal,
    name: (string-utf8 50),
    specialty: (string-ascii 100),
    verified: bool,
    artifacts-curated: uint,
    reputation-score: uint,
    joined-at: uint
  }
)

(define-map curator-lookup
  { curator-address: principal }
  { curator-id: uint }
)

(define-map artifact-votes
  { artifact-id: uint, voter: principal }
  { vote-type: bool, timestamp: uint }
)

(define-map artifact-access
  { artifact-id: uint, accessor: principal }
  { granted: bool, granted-at: uint }
)

(define-map categories
  { category-name: (string-ascii 50) }
  { active: bool, artifact-count: uint }
)

(define-map user-contributions
  { user: principal }
  { total-artifacts: uint, total-votes: uint, reputation: uint }
)

(define-map marketplace-listings
  { listing-id: uint }
  {
    artifact-id: uint,
    seller: principal,
    price: uint,
    listed-at: uint,
    active: bool,
    expires-at: uint
  }
)

(define-map artifact-sales-history
  { artifact-id: uint, sale-id: uint }
  {
    seller: principal,
    buyer: principal,
    price: uint,
    sold-at: uint,
    marketplace-fee: uint
  }
)

(define-map user-earnings
  { user: principal }
  { total-sales: uint, total-earned: uint, total-fees-paid: uint }
)

(define-map artifact-listing-lookup
  { artifact-id: uint }
  { listing-id: uint }
)

(define-public (register-curator (name (string-utf8 50)) (specialty (string-ascii 100)))
  (let 
    (
      (curator-id (var-get next-curator-id))
      (current-block stacks-block-height)
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-none (map-get? curator-lookup { curator-address: tx-sender })) err-already-exists)
    (asserts! (> (len name) u0) err-invalid-data)
    (asserts! (> (len specialty) u0) err-invalid-data)
    
    (map-set curators
      { curator-id: curator-id }
      {
        curator-address: tx-sender,
        name: name,
        specialty: specialty,
        verified: false,
        artifacts-curated: u0,
        reputation-score: u0,
        joined-at: current-block
      }
    )
    
    (map-set curator-lookup
      { curator-address: tx-sender }
      { curator-id: curator-id }
    )
    
    (var-set next-curator-id (+ curator-id u1))
    (ok curator-id)
  )
)

(define-public (verify-curator (curator-id uint))
  (let ((curator (unwrap! (map-get? curators { curator-id: curator-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get verified curator)) err-already-exists)
    
    (map-set curators
      { curator-id: curator-id }
      (merge curator { verified: true })
    )
    (ok true)
  )
)

(define-public (create-category (category-name (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len category-name) u0) err-invalid-data)
    (asserts! (is-none (map-get? categories { category-name: category-name })) err-already-exists)
    
    (map-set categories
      { category-name: category-name }
      { active: true, artifact-count: u0 }
    )
    (ok true)
  )
)

(define-public (submit-artifact 
  (title (string-ascii 100))
  (description (string-utf8 500))
  (content-hash (string-ascii 64))
  (category (string-ascii 50))
  (origin-location (string-utf8 100))
  (access-level uint)
)
  (let 
    (
      (artifact-id (var-get next-artifact-id))
      (current-block stacks-block-height)
      (curator-data (map-get? curator-lookup { curator-address: tx-sender }))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (> (len title) u0) err-invalid-data)
    (asserts! (> (len description) u0) err-invalid-data)
    (asserts! (> (len content-hash) u0) err-invalid-data)
    (asserts! (is-some (map-get? categories { category-name: category })) err-invalid-category)
    (asserts! (<= access-level u3) err-invalid-data)
    
    (map-set artifacts
      { artifact-id: artifact-id }
      {
        title: title,
        description: description,
        content-hash: content-hash,
        category: category,
        origin-location: origin-location,
        creator: tx-sender,
        curator: tx-sender,
        timestamp: (unwrap-panic (get-stacks-block-info? time current-block)),
        block-height: current-block,
        verified: false,
        vote-count: u0,
        access-level: access-level,
        for-sale: false,
        sale-price: u0,
        owner: tx-sender
      }
    )
    
    (match curator-data
      curator-info 
        (let ((curator-id (get curator-id curator-info)))
          (match (map-get? curators { curator-id: curator-id })
            curator-details
              (map-set curators
                { curator-id: curator-id }
                (merge curator-details { artifacts-curated: (+ (get artifacts-curated curator-details) u1) })
              )
            true
          )
        )
      true
    )
    
    (let ((category-info (unwrap-panic (map-get? categories { category-name: category }))))
      (map-set categories
        { category-name: category }
        (merge category-info { artifact-count: (+ (get artifact-count category-info) u1) })
      )
    )
    
    (let ((user-contrib (default-to { total-artifacts: u0, total-votes: u0, reputation: u0 }
                                   (map-get? user-contributions { user: tx-sender }))))
      (map-set user-contributions
        { user: tx-sender }
        (merge user-contrib { total-artifacts: (+ (get total-artifacts user-contrib) u1) })
      )
    )
    
    (var-set next-artifact-id (+ artifact-id u1))
    (ok artifact-id)
  )
)

(define-public (vote-artifact (artifact-id uint) (vote-type bool))
  (let 
    (
      (artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found))
      (existing-vote (map-get? artifact-votes { artifact-id: artifact-id, voter: tx-sender }))
      (current-block stacks-block-height)
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-none existing-vote) err-already-exists)
    (asserts! (not (is-eq tx-sender (get creator artifact))) err-unauthorized)
    
    (map-set artifact-votes
      { artifact-id: artifact-id, voter: tx-sender }
      { vote-type: vote-type, timestamp: (unwrap-panic (get-stacks-block-info? time current-block)) }
    )
    
    (map-set artifacts
      { artifact-id: artifact-id }
      (merge artifact { vote-count: (+ (get vote-count artifact) u1) })
    )
    
    (let ((user-contrib (default-to { total-artifacts: u0, total-votes: u0, reputation: u0 }
                                   (map-get? user-contributions { user: tx-sender }))))
      (map-set user-contributions
        { user: tx-sender }
        (merge user-contrib { 
          total-votes: (+ (get total-votes user-contrib) u1),
          reputation: (+ (get reputation user-contrib) u1)
        })
      )
    )
    
    (ok true)
  )
)

(define-public (verify-artifact (artifact-id uint))
  (let ((artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get verified artifact)) err-already-exists)
    
    (map-set artifacts
      { artifact-id: artifact-id }
      (merge artifact { verified: true })
    )
    
    (let ((creator (get creator artifact)))
      (let ((user-contrib (default-to { total-artifacts: u0, total-votes: u0, reputation: u0 }
                                     (map-get? user-contributions { user: creator }))))
        (map-set user-contributions
          { user: creator }
          (merge user-contrib { reputation: (+ (get reputation user-contrib) u5) })
        )
      )
    )
    
    (ok true)
  )
)

(define-public (grant-access (artifact-id uint) (accessor principal))
  (let ((artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found)))
    (asserts! (or (is-eq tx-sender (get creator artifact)) (is-eq tx-sender contract-owner)) err-unauthorized)
    (asserts! (> (get access-level artifact) u0) err-unauthorized)
    
    (map-set artifact-access
      { artifact-id: artifact-id, accessor: accessor }
      { granted: true, granted-at: stacks-block-height }
    )
    (ok true)
  )
)

(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

(define-public (list-artifact-for-sale (artifact-id uint) (price uint) (duration-blocks uint))
  (let 
    (
      (artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found))
      (listing-id (var-get next-listing-id))
      (current-block stacks-block-height)
      (expires-at (+ current-block duration-blocks))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get owner artifact)) err-unauthorized)
    (asserts! (not (get for-sale artifact)) err-already-exists)
    (asserts! (> price u0) err-invalid-price)
    (asserts! (> duration-blocks u0) err-invalid-data)
    (asserts! (<= duration-blocks u4320) err-invalid-data)
    
    (map-set artifacts
      { artifact-id: artifact-id }
      (merge artifact { for-sale: true, sale-price: price })
    )
    
    (map-set marketplace-listings
      { listing-id: listing-id }
      {
        artifact-id: artifact-id,
        seller: tx-sender,
        price: price,
        listed-at: current-block,
        active: true,
        expires-at: expires-at
      }
    )
    
    (map-set artifact-listing-lookup
      { artifact-id: artifact-id }
      { listing-id: listing-id }
    )
    
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (update-listing-price (artifact-id uint) (new-price uint))
  (let 
    (
      (artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found))
      (listing-lookup (unwrap! (map-get? artifact-listing-lookup { artifact-id: artifact-id }) err-not-found))
      (listing (unwrap! (map-get? marketplace-listings { listing-id: (get listing-id listing-lookup) }) err-not-found))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get owner artifact)) err-unauthorized)
    (asserts! (get for-sale artifact) err-not-for-sale)
    (asserts! (get active listing) err-not-for-sale)
    (asserts! (> new-price u0) err-invalid-price)
    (asserts! (<= stacks-block-height (get expires-at listing)) err-not-found)
    
    (map-set artifacts
      { artifact-id: artifact-id }
      (merge artifact { sale-price: new-price })
    )
    
    (map-set marketplace-listings
      { listing-id: (get listing-id listing-lookup) }
      (merge listing { price: new-price })
    )
    
    (ok true)
  )
)

(define-public (cancel-listing (artifact-id uint))
  (let 
    (
      (artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found))
      (listing-lookup (unwrap! (map-get? artifact-listing-lookup { artifact-id: artifact-id }) err-not-found))
      (listing (unwrap! (map-get? marketplace-listings { listing-id: (get listing-id listing-lookup) }) err-not-found))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get owner artifact)) err-unauthorized)
    (asserts! (get for-sale artifact) err-not-for-sale)
    (asserts! (get active listing) err-not-for-sale)
    
    (map-set artifacts
      { artifact-id: artifact-id }
      (merge artifact { for-sale: false, sale-price: u0 })
    )
    
    (map-set marketplace-listings
      { listing-id: (get listing-id listing-lookup) }
      (merge listing { active: false })
    )
    
    (map-delete artifact-listing-lookup { artifact-id: artifact-id })
    (ok true)
  )
)

(define-public (buy-artifact (artifact-id uint))
  (let 
    (
      (artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found))
      (listing-lookup (unwrap! (map-get? artifact-listing-lookup { artifact-id: artifact-id }) err-not-found))
      (listing (unwrap! (map-get? marketplace-listings { listing-id: (get listing-id listing-lookup) }) err-not-found))
      (sale-price (get price listing))
      (marketplace-fee (/ (* sale-price (var-get marketplace-fee-rate)) u10000))
      (seller-amount (- sale-price marketplace-fee))
      (current-block stacks-block-height)
      (sale-id (get vote-count artifact))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (get for-sale artifact) err-not-for-sale)
    (asserts! (get active listing) err-not-for-sale)
    (asserts! (<= current-block (get expires-at listing)) err-not-found)
    (asserts! (not (is-eq tx-sender (get owner artifact))) err-cannot-buy-own-artifact)
    
    (unwrap! (stx-transfer? sale-price tx-sender (get seller listing)) err-transfer-failed)
    
    (map-set artifacts
      { artifact-id: artifact-id }
      (merge artifact { 
        owner: tx-sender,
        for-sale: false,
        sale-price: u0
      })
    )
    
    (map-set marketplace-listings
      { listing-id: (get listing-id listing-lookup) }
      (merge listing { active: false })
    )
    
    (map-set artifact-sales-history
      { artifact-id: artifact-id, sale-id: sale-id }
      {
        seller: (get seller listing),
        buyer: tx-sender,
        price: sale-price,
        sold-at: current-block,
        marketplace-fee: marketplace-fee
      }
    )
    
    (let ((seller-earnings (default-to { total-sales: u0, total-earned: u0, total-fees-paid: u0 }
                                      (map-get? user-earnings { user: (get seller listing) }))))
      (map-set user-earnings
        { user: (get seller listing) }
        (merge seller-earnings { 
          total-sales: (+ (get total-sales seller-earnings) u1),
          total-earned: (+ (get total-earned seller-earnings) seller-amount),
          total-fees-paid: (+ (get total-fees-paid seller-earnings) marketplace-fee)
        })
      )
    )
    
    (map-delete artifact-listing-lookup { artifact-id: artifact-id })
    (ok true)
  )
)

(define-public (transfer-artifact (artifact-id uint) (new-owner principal))
  (let ((artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found)))
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get owner artifact)) err-unauthorized)
    (asserts! (not (get for-sale artifact)) err-not-for-sale)
    (asserts! (not (is-eq tx-sender new-owner)) err-invalid-data)
    
    (map-set artifacts
      { artifact-id: artifact-id }
      (merge artifact { owner: new-owner })
    )
    (ok true)
  )
)

(define-public (set-marketplace-fee (new-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-rate u1000) err-invalid-data)
    (var-set marketplace-fee-rate new-fee-rate)
    (ok new-fee-rate)
  )
)

(define-read-only (get-artifact (artifact-id uint))
  (map-get? artifacts { artifact-id: artifact-id })
)

(define-read-only (get-curator (curator-id uint))
  (map-get? curators { curator-id: curator-id })
)

(define-read-only (get-curator-by-address (curator-address principal))
  (match (map-get? curator-lookup { curator-address: curator-address })
    curator-info (map-get? curators { curator-id: (get curator-id curator-info) })
    none
  )
)

(define-read-only (get-artifact-vote (artifact-id uint) (voter principal))
  (map-get? artifact-votes { artifact-id: artifact-id, voter: voter })
)

(define-read-only (has-access (artifact-id uint) (accessor principal))
  (let ((artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) (err u404))))
    (if (is-eq (get access-level artifact) u0)
      (ok true)
      (if (or (is-eq accessor (get creator artifact)) (is-eq accessor contract-owner))
        (ok true)
        (match (map-get? artifact-access { artifact-id: artifact-id, accessor: accessor })
          access-info (ok (get granted access-info))
          (ok false)
        )
      )
    )
  )
)

(define-read-only (get-category-info (category-name (string-ascii 50)))
  (map-get? categories { category-name: category-name })
)

(define-read-only (get-user-contributions (user principal))
  (map-get? user-contributions { user: user })
)

(define-read-only (get-contract-stats)
  {
    total-artifacts: (- (var-get next-artifact-id) u1),
    total-curators: (- (var-get next-curator-id) u1),
    contract-paused: (var-get contract-paused),
    contract-owner: contract-owner
  }
)

(define-read-only (get-current-block-info)
  {
    height: stacks-block-height,
    time: (default-to u0 (get-stacks-block-info? time stacks-block-height))
  }
)

(define-read-only (get-marketplace-listing (listing-id uint))
  (map-get? marketplace-listings { listing-id: listing-id })
)

(define-read-only (get-artifact-listing (artifact-id uint))
  (match (map-get? artifact-listing-lookup { artifact-id: artifact-id })
    listing-lookup (map-get? marketplace-listings { listing-id: (get listing-id listing-lookup) })
    none
  )
)

(define-read-only (get-artifact-sales-history (artifact-id uint) (sale-id uint))
  (map-get? artifact-sales-history { artifact-id: artifact-id, sale-id: sale-id })
)

(define-read-only (get-user-earnings (user principal))
  (map-get? user-earnings { user: user })
)

(define-read-only (get-marketplace-stats)
  {
    total-listings: (- (var-get next-listing-id) u1),
    marketplace-fee-rate: (var-get marketplace-fee-rate),
    contract-owner: contract-owner
  }
)

(define-read-only (is-artifact-for-sale (artifact-id uint))
  (match (map-get? artifacts { artifact-id: artifact-id })
    artifact (get for-sale artifact)
    false
  )
)

(define-read-only (get-artifact-price (artifact-id uint))
  (match (map-get? artifacts { artifact-id: artifact-id })
    artifact (get sale-price artifact)
    u0
  )
)

(define-read-only (get-artifact-owner (artifact-id uint))
  (match (map-get? artifacts { artifact-id: artifact-id })
    artifact (some (get owner artifact))
    none
  )
)
