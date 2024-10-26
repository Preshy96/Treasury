;; Community Treasury Smart Contract
;; Manages community funds with governance features
;; Implements proposal voting, fund management, and security measures

;; Error codes
(define-constant ERROR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERROR-INSUFFICIENT-TREASURY-BALANCE (err u101))
(define-constant ERROR-INVALID-TRANSACTION-AMOUNT (err u102))
(define-constant ERROR-PROPOSAL-NOT-EXISTING (err u103))
(define-constant ERROR-MEMBER-ALREADY-VOTED (err u104))
(define-constant ERROR-PROPOSAL-VOTING-PERIOD-ENDED (err u105))
(define-constant ERROR-MINIMUM-PROPOSAL-DEPOSIT-NOT-MET (err u106))

;; Constants
(define-constant PROPOSAL-VOTING-PERIOD-BLOCKS u10000) ;; Number of blocks proposal stays active
(define-constant MINIMUM-PROPOSAL-DEPOSIT u1000000) ;; Minimum deposit in microSTX
(define-constant PROPOSAL-QUORUM-THRESHOLD u500) ;; 50% of total votes needed
(define-constant PROPOSAL-APPROVAL-THRESHOLD u510) ;; 51% yes votes needed for approval

;; Data vars
(define-data-var total-treasury-balance uint u0)
(define-data-var total-proposals-count uint u0)
(define-data-var treasury-administrator principal tx-sender)

;; Maps
(define-map treasury-proposals
    uint
    {
        proposal-creator: principal,
        requested-amount: uint,
        funds-recipient: principal,
        proposal-description: (string-utf8 256),
        total-yes-votes: uint,
        total-no-votes: uint,
        proposal-start-block: uint,
        proposal-executed: bool,
        proposal-deposit-amount: uint
    }
)

(define-map member-voting-records
    {proposal-identifier: uint, member-address: principal}
    bool
)

(define-map member-treasury-deposits principal uint)

;; Read-only functions
(define-read-only (get-total-treasury-balance)
    (var-get total-treasury-balance)
)

(define-read-only (get-proposal-details (proposal-identifier uint))
    (map-get? treasury-proposals proposal-identifier)
)

(define-read-only (check-member-vote-status (proposal-identifier uint) (member-address principal))
    (default-to false (map-get? member-voting-records 
        {proposal-identifier: proposal-identifier, member-address: member-address}))
)

(define-read-only (get-member-total-deposits (member-address principal))
    (default-to u0 (map-get? member-treasury-deposits member-address))
)

;; Private functions
(define-private (is-proposal-voting-active (proposal-identifier uint))
    (let (
        (proposal-data (unwrap! (get-proposal-details proposal-identifier) false))
        (current-block-height block-height)
    )
    (and
        (>= current-block-height (get proposal-start-block proposal-data))
        (< current-block-height (+ (get proposal-start-block proposal-data) PROPOSAL_VOTING_PERIOD_BLOCKS))
        (not (get proposal-executed proposal-data))
    ))
)

(define-private (check-proposal-quorum-reached (total-yes-votes uint) (total-no-votes uint))
    (let (
        (combined-vote-count (+ total-yes-votes total-no-votes))
    )
    (and
        (>= combined-vote-count PROPOSAL_QUORUM_THRESHOLD)
        (>= (* total-yes-votes u1000) (* PROPOSAL_APPROVAL_THRESHOLD combined-vote-count))
    ))
)

;; Public functions
(define-public (deposit-funds)
    (let (
        (deposit-amount (stx-get-balance tx-sender))
        (existing-member-deposit (get-member-total-deposits tx-sender))
    )
    (begin
        (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
        (var-set total-treasury-balance (+ (var-get total-treasury-balance) deposit-amount))
        (map-set member-treasury-deposits tx-sender (+ existing-member-deposit deposit-amount))
        (ok deposit-amount)
    ))
)

(define-public (submit-new-proposal (requested-amount uint) (funds-recipient principal) (proposal-description (string-utf8 256)))
    (let (
        (proposal-identifier (var-get total-proposals-count))
        (proposal-deposit (try! (stx-transfer? MINIMUM_PROPOSAL_DEPOSIT tx-sender (as-contract tx-sender))))
    )
    (begin
        (asserts! (>= requested-amount u0) ERROR-INVALID-TRANSACTION-AMOUNT)
        (asserts! (<= requested-amount (var-get total-treasury-balance)) ERROR-INSUFFICIENT-TREASURY-BALANCE)
        
        (map-set treasury-proposals proposal-identifier {
            proposal-creator: tx-sender,
            requested-amount: requested-amount,
            funds-recipient: funds-recipient,
            proposal-description: proposal-description,
            total-yes-votes: u0,
            total-no-votes: u0,
            proposal-start-block: block-height,
            proposal-executed: false,
            proposal-deposit-amount: MINIMUM_PROPOSAL_DEPOSIT
        })
        
        (var-set total-proposals-count (+ proposal-identifier u1))
        (ok proposal-identifier)
    ))
)

(define-public (cast-vote (proposal-identifier uint) (support-proposal bool))
    (let (
        (proposal-data (unwrap! (get-proposal-details proposal-identifier) ERROR-PROPOSAL-NOT-EXISTING))
    )
    (begin
        (asserts! (is-proposal-voting-active proposal-identifier) ERROR-PROPOSAL-VOTING-PERIOD-ENDED)
        (asserts! (not (check-member-vote-status proposal-identifier tx-sender)) ERROR-MEMBER-ALREADY-VOTED)
        
        (map-set member-voting-records 
            {proposal-identifier: proposal-identifier, member-address: tx-sender} 
            true)
        
        (if support-proposal
            (map-set treasury-proposals proposal-identifier 
                (merge proposal-data {total-yes-votes: (+ (get total-yes-votes proposal-data) u1)}))
            (map-set treasury-proposals proposal-identifier 
                (merge proposal-data {total-no-votes: (+ (get total-no-votes proposal-data) u1)}))
        )
        
        (ok true)
    ))
)

(define-public (execute-approved-proposal (proposal-identifier uint))
    (let (
        (proposal-data (unwrap! (get-proposal-details proposal-identifier) ERROR-PROPOSAL-NOT-EXISTING))
    )
    (begin
        (asserts! (not (get proposal-executed proposal-data)) ERROR-PROPOSAL-VOTING-PERIOD-ENDED)
        (asserts! (check-proposal-quorum-reached 
            (get total-yes-votes proposal-data) 
            (get total-no-votes proposal-data)) 
            ERROR-UNAUTHORIZED-ACCESS)
        
        ;; Execute the transfer
        (try! (as-contract (stx-transfer? (get requested-amount proposal-data) 
                                        tx-sender 
                                        (get funds-recipient proposal-data))))
        
        ;; Update treasury balance
        (var-set total-treasury-balance 
            (- (var-get total-treasury-balance) (get requested-amount proposal-data)))
        
        ;; Return deposit to proposer
        (try! (as-contract (stx-transfer? (get proposal-deposit-amount proposal-data)
                                        tx-sender
                                        (get proposal-creator proposal-data))))
        
        ;; Mark proposal as executed
        (map-set treasury-proposals proposal-identifier 
            (merge proposal-data {proposal-executed: true}))
            
        (ok true)
    ))
)

;; Admin functions
(define-public (transfer-admin-rights (new-administrator principal))
    (begin
        (asserts! (is-eq tx-sender (var-get treasury-administrator)) ERROR-UNAUTHORIZED-ACCESS)
        (var-set treasury-administrator new-administrator)
        (ok true)
    ))

;; Emergency functions
(define-public (emergency-treasury-shutdown)
    (begin
        (asserts! (is-eq tx-sender (var-get treasury-administrator)) ERROR-UNAUTHORIZED-ACCESS)
        (as-contract (stx-transfer? (var-get total-treasury-balance)
                                  tx-sender
                                  (var-get treasury-administrator)))
        (var-set total-treasury-balance u0)
        (ok true)
    ))