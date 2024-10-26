# Community Treasury Smart Contract

## About
The Community Treasury Smart Contract is a decentralized financial management system built on the Stacks blockchain using Clarity. It enables community members to collectively manage funds through a democratic proposal and voting system.

## Features
- Treasury Management
- Proposal System
- Voting Mechanism
- Security Controls
- Emergency Functions

## Technical Specifications

### Constants
- `PROPOSAL_DURATION`: 10000 blocks
- `MIN_DEPOSIT`: 1,000,000 microSTX
- `QUORUM_THRESHOLD`: 50% (500/1000)
- `MAJORITY_THRESHOLD`: 51% (510/1000)

### Error Codes
| Code | Description |
|------|-------------|
| 100 | Not Authorized |
| 101 | Insufficient Balance |
| 102 | Invalid Amount |
| 103 | Proposal Not Found |
| 104 | Already Voted |
| 105 | Proposal Expired |
| 106 | Minimum Deposit Not Met |

## Functions

### Public Functions

#### 1. Deposit Funds
```clarity
(deposit)
```
Allows members to deposit STX into the treasury.

**Returns:**
- `(ok uint)`: Amount deposited
- `(err uint)`: Error code if transaction fails

#### 2. Create Proposal
```clarity
(create-proposal (amount uint) (recipient principal) (description (string-utf8 256)))
```
Creates a new proposal for fund allocation.

**Parameters:**
- `amount`: Amount of STX to transfer
- `recipient`: Recipient address
- `description`: Proposal description

**Returns:**
- `(ok uint)`: Proposal ID
- `(err uint)`: Error code if creation fails

#### 3. Vote on Proposal
```clarity
(vote (proposal-id uint) (vote-for bool))
```
Casts a vote on an existing proposal.

**Parameters:**
- `proposal-id`: ID of the proposal
- `vote-for`: true for yes, false for no

**Returns:**
- `(ok bool)`: Success confirmation
- `(err uint)`: Error code if vote fails

#### 4. Execute Proposal
```clarity
(execute-proposal (proposal-id uint))
```
Executes an approved proposal.

**Parameters:**
- `proposal-id`: ID of the proposal

**Returns:**
- `(ok bool)`: Success confirmation
- `(err uint)`: Error code if execution fails

### Read-Only Functions

#### 1. Get Treasury Balance
```clarity
(get-treasury-balance)
```
Returns current treasury balance.

#### 2. Get Proposal Details
```clarity
(get-proposal (proposal-id uint))
```
Returns details of a specific proposal.

#### 3. Check Vote Status
```clarity
(has-voted (proposal-id uint) (voter principal))
```
Checks if an address has voted on a specific proposal.

#### 4. Get Member Deposit
```clarity
(get-member-deposit (member principal))
```
Returns total deposits made by a member.

### Admin Functions

#### 1. Change Admin
```clarity
(change-admin (new-admin principal))
```
Transfers admin rights to a new address.

#### 2. Emergency Shutdown
```clarity
(emergency-shutdown)
```
Allows admin to withdraw all funds in case of emergency.

## Security Considerations

### Deposit Protection
- All deposits are tracked and linked to member addresses
- Minimum deposit requirement for proposals prevents spam
- Deposits are returned after proposal execution

### Voting Security
- One vote per address per proposal
- Anti-double voting mechanism
- Time-locked proposal duration
- Quorum and majority thresholds

### Administrative Controls
- Admin privileges for emergency situations
- Controlled admin transfer process
- Emergency shutdown capability

## Implementation Guide

## Best Practices
1. Always check return values for errors
2. Verify proposal details before voting
3. Ensure sufficient balance before creating proposals
4. Monitor proposal deadlines
5. Keep private keys secure for admin functions

## Common Pitfalls to Avoid
1. Not checking if a proposal is still active before voting
2. Forgetting to include minimum deposit with proposal
3. Attempting to execute proposal before quorum is reached
4. Not verifying recipient address in proposals
5. Ignoring return values from contract calls

## Testing
The contract includes comprehensive test cases covering:
- Deposit functionality
- Proposal creation and execution
- Voting mechanism
- Security controls
- Error handling