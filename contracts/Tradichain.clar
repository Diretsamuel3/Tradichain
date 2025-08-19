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
(define-constant err-collaboration-exists (err u112))
(define-constant err-invalid-percentage (err u113))
(define-constant err-not-collaborator (err u114))
(define-constant err-collaboration-not-found (err u115))
(define-constant err-pending-invitations (err u116))
(define-constant err-invitation-expired (err u117))
(define-constant err-invalid-role (err u118))

(define-data-var next-artifact-id uint u1)
(define-data-var next-curator-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var next-listing-id uint u1)
(define-data-var marketplace-fee-rate uint u250)
(define-data-var next-collaboration-id uint u1)
(define-data-var collaboration-invitation-duration uint u1440)

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

(define-map artifact-collaborations
  { collaboration-id: uint }
  {
    artifact-id: uint,
    lead-collaborator: principal,
    total-collaborators: uint,
    status: uint,
    created-at: uint,
    finalized-at: uint,
    revenue-pool: uint,
    active: bool
  }
)

(define-map collaboration-participants
  { collaboration-id: uint, participant: principal }
  {
    role: uint,
    contribution-percentage: uint,
    earnings-claimed: uint,
    joined-at: uint,
    active: bool
  }
)

(define-map collaboration-invitations
  { collaboration-id: uint, invitee: principal }
  {
    role: uint,
    percentage: uint,
    invited-by: principal,
    invited-at: uint,
    expires-at: uint,
    status: uint
  }
)

(define-map collaboration-lookup
  { artifact-id: uint }
  { collaboration-id: uint }
)

(define-map collaboration-earnings
  { collaboration-id: uint }
  {
    total-revenue: uint,
    total-distributed: uint,
    pending-distribution: uint,
    last-distribution: uint
  }
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

(define-public (create-collaboration (artifact-id uint))
  (let 
    (
      (artifact (unwrap! (map-get? artifacts { artifact-id: artifact-id }) err-not-found))
      (collaboration-id (var-get next-collaboration-id))
      (current-block stacks-block-height)
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get owner artifact)) err-unauthorized)
    (asserts! (is-none (map-get? collaboration-lookup { artifact-id: artifact-id })) err-collaboration-exists)
    
    (map-set artifact-collaborations
      { collaboration-id: collaboration-id }
      {
        artifact-id: artifact-id,
        lead-collaborator: tx-sender,
        total-collaborators: u1,
        status: u1,
        created-at: current-block,
        finalized-at: u0,
        revenue-pool: u0,
        active: true
      }
    )
    
    (map-set collaboration-participants
      { collaboration-id: collaboration-id, participant: tx-sender }
      {
        role: u1,
        contribution-percentage: u10000,
        earnings-claimed: u0,
        joined-at: current-block,
        active: true
      }
    )
    
    (map-set collaboration-lookup
      { artifact-id: artifact-id }
      { collaboration-id: collaboration-id }
    )
    
    (map-set collaboration-earnings
      { collaboration-id: collaboration-id }
      {
        total-revenue: u0,
        total-distributed: u0,
        pending-distribution: u0,
        last-distribution: u0
      }
    )
    
    (var-set next-collaboration-id (+ collaboration-id u1))
    (ok collaboration-id)
  )
)

(define-public (invite-collaborator 
  (collaboration-id uint) 
  (invitee principal) 
  (role uint) 
  (percentage uint)
)
  (let 
    (
      (collaboration (unwrap! (map-get? artifact-collaborations { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (current-block stacks-block-height)
      (expires-at (+ current-block (var-get collaboration-invitation-duration)))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get lead-collaborator collaboration)) err-unauthorized)
    (asserts! (get active collaboration) err-collaboration-not-found)
    (asserts! (is-eq (get status collaboration) u1) err-invalid-data)
    (asserts! (and (>= role u1) (<= role u4)) err-invalid-role)
    (asserts! (and (> percentage u0) (<= percentage u10000)) err-invalid-percentage)
    (asserts! (is-none (map-get? collaboration-invitations { collaboration-id: collaboration-id, invitee: invitee })) err-already-exists)
    (asserts! (is-none (map-get? collaboration-participants { collaboration-id: collaboration-id, participant: invitee })) err-already-exists)
    
    (map-set collaboration-invitations
      { collaboration-id: collaboration-id, invitee: invitee }
      {
        role: role,
        percentage: percentage,
        invited-by: tx-sender,
        invited-at: current-block,
        expires-at: expires-at,
        status: u1
      }
    )
    (ok true)
  )
)

(define-public (accept-collaboration-invitation (collaboration-id uint))
  (let 
    (
      (invitation (unwrap! (map-get? collaboration-invitations { collaboration-id: collaboration-id, invitee: tx-sender }) err-not-found))
      (collaboration (unwrap! (map-get? artifact-collaborations { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (current-block stacks-block-height)
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq (get status invitation) u1) err-not-found)
    (asserts! (<= current-block (get expires-at invitation)) err-invitation-expired)
    (asserts! (get active collaboration) err-collaboration-not-found)
    
    (map-set collaboration-participants
      { collaboration-id: collaboration-id, participant: tx-sender }
      {
        role: (get role invitation),
        contribution-percentage: (get percentage invitation),
        earnings-claimed: u0,
        joined-at: current-block,
        active: true
      }
    )
    
    (map-set collaboration-invitations
      { collaboration-id: collaboration-id, invitee: tx-sender }
      (merge invitation { status: u2 })
    )
    
    (map-set artifact-collaborations
      { collaboration-id: collaboration-id }
      (merge collaboration { total-collaborators: (+ (get total-collaborators collaboration) u1) })
    )
    
    (ok true)
  )
)

(define-public (decline-collaboration-invitation (collaboration-id uint))
  (let 
    (
      (invitation (unwrap! (map-get? collaboration-invitations { collaboration-id: collaboration-id, invitee: tx-sender }) err-not-found))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq (get status invitation) u1) err-not-found)
    
    (map-set collaboration-invitations
      { collaboration-id: collaboration-id, invitee: tx-sender }
      (merge invitation { status: u3 })
    )
    (ok true)
  )
)

(define-public (finalize-collaboration (collaboration-id uint))
  (let 
    (
      (collaboration (unwrap! (map-get? artifact-collaborations { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (current-block stacks-block-height)
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get lead-collaborator collaboration)) err-unauthorized)
    (asserts! (is-eq (get status collaboration) u1) err-invalid-data)
    (asserts! (get active collaboration) err-collaboration-not-found)
    
    (map-set artifact-collaborations
      { collaboration-id: collaboration-id }
      (merge collaboration { 
        status: u2,
        finalized-at: current-block
      })
    )
    (ok true)
  )
)

(define-public (leave-collaboration (collaboration-id uint))
  (let 
    (
      (collaboration (unwrap! (map-get? artifact-collaborations { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (participant (unwrap! (map-get? collaboration-participants { collaboration-id: collaboration-id, participant: tx-sender }) err-not-collaborator))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (not (is-eq tx-sender (get lead-collaborator collaboration))) err-unauthorized)
    (asserts! (get active participant) err-not-collaborator)
    (asserts! (is-eq (get status collaboration) u1) err-invalid-data)
    
    (map-set collaboration-participants
      { collaboration-id: collaboration-id, participant: tx-sender }
      (merge participant { active: false })
    )
    
    (map-set artifact-collaborations
      { collaboration-id: collaboration-id }
      (merge collaboration { total-collaborators: (- (get total-collaborators collaboration) u1) })
    )
    (ok true)
  )
)

(define-public (distribute-collaboration-revenue (collaboration-id uint) (amount uint))
  (let 
    (
      (collaboration (unwrap! (map-get? artifact-collaborations { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (earnings (unwrap! (map-get? collaboration-earnings { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (current-block stacks-block-height)
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get lead-collaborator collaboration)) err-unauthorized)
    (asserts! (is-eq (get status collaboration) u2) err-invalid-data)
    (asserts! (> amount u0) err-invalid-data)
    
    (map-set collaboration-earnings
      { collaboration-id: collaboration-id }
      (merge earnings {
        total-revenue: (+ (get total-revenue earnings) amount),
        pending-distribution: (+ (get pending-distribution earnings) amount),
        last-distribution: current-block
      })
    )
    
    (map-set artifact-collaborations
      { collaboration-id: collaboration-id }
      (merge collaboration { revenue-pool: (+ (get revenue-pool collaboration) amount) })
    )
    (ok true)
  )
)

(define-public (claim-collaboration-earnings (collaboration-id uint))
  (let 
    (
      (collaboration (unwrap! (map-get? artifact-collaborations { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (participant (unwrap! (map-get? collaboration-participants { collaboration-id: collaboration-id, participant: tx-sender }) err-not-collaborator))
      (earnings (unwrap! (map-get? collaboration-earnings { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (user-share (/ (* (get pending-distribution earnings) (get contribution-percentage participant)) u10000))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (get active participant) err-not-collaborator)
    (asserts! (is-eq (get status collaboration) u2) err-invalid-data)
    (asserts! (> user-share u0) err-invalid-data)
    
    (unwrap! (stx-transfer? user-share (get lead-collaborator collaboration) tx-sender) err-transfer-failed)
    
    (map-set collaboration-participants
      { collaboration-id: collaboration-id, participant: tx-sender }
      (merge participant { earnings-claimed: (+ (get earnings-claimed participant) user-share) })
    )
    
    (map-set collaboration-earnings
      { collaboration-id: collaboration-id }
      (merge earnings { 
        total-distributed: (+ (get total-distributed earnings) user-share),
        pending-distribution: (- (get pending-distribution earnings) user-share)
      })
    )
    
    (map-set artifact-collaborations
      { collaboration-id: collaboration-id }
      (merge collaboration { revenue-pool: (- (get revenue-pool collaboration) user-share) })
    )
    (ok user-share)
  )
)

(define-public (update-participant-percentage (collaboration-id uint) (participant principal) (new-percentage uint))
  (let 
    (
      (collaboration (unwrap! (map-get? artifact-collaborations { collaboration-id: collaboration-id }) err-collaboration-not-found))
      (participant-data (unwrap! (map-get? collaboration-participants { collaboration-id: collaboration-id, participant: participant }) err-not-collaborator))
    )
    (asserts! (not (var-get contract-paused)) (err u106))
    (asserts! (is-eq tx-sender (get lead-collaborator collaboration)) err-unauthorized)
    (asserts! (is-eq (get status collaboration) u1) err-invalid-data)
    (asserts! (and (> new-percentage u0) (<= new-percentage u10000)) err-invalid-percentage)
    (asserts! (get active participant-data) err-not-collaborator)
    
    (map-set collaboration-participants
      { collaboration-id: collaboration-id, participant: participant }
      (merge participant-data { contribution-percentage: new-percentage })
    )
    (ok true)
  )
)

(define-read-only (get-collaboration (collaboration-id uint))
  (map-get? artifact-collaborations { collaboration-id: collaboration-id })
)

(define-read-only (get-collaboration-participant (collaboration-id uint) (participant principal))
  (map-get? collaboration-participants { collaboration-id: collaboration-id, participant: participant })
)

(define-read-only (get-collaboration-invitation (collaboration-id uint) (invitee principal))
  (map-get? collaboration-invitations { collaboration-id: collaboration-id, invitee: invitee })
)

(define-read-only (get-artifact-collaboration (artifact-id uint))
  (match (map-get? collaboration-lookup { artifact-id: artifact-id })
    lookup (map-get? artifact-collaborations { collaboration-id: (get collaboration-id lookup) })
    none
  )
)

(define-read-only (get-collaboration-earnings-info (collaboration-id uint))
  (map-get? collaboration-earnings { collaboration-id: collaboration-id })
)

(define-read-only (get-collaboration-stats)
  {
    total-collaborations: (- (var-get next-collaboration-id) u1),
    invitation-duration: (var-get collaboration-invitation-duration)
  }
)


