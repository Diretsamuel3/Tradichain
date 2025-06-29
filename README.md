# Tradichain - Cultural Knowledge Vault

A blockchain-based platform for preserving and sharing oral history, cultural traditions, and indigenous knowledge on the Stacks network.

## Overview

Tradichain enables communities to store, verify, and share their cultural artifacts while maintaining control over access and authenticity. The platform features curator registration, artifact submission with categorization, community voting, and flexible access controls.

## Features

- **Cultural Artifact Storage**: Submit stories, traditions, and historical content with metadata
- **Curator System**: Register as cultural specialists with verification capabilities  
- **Community Voting**: Vote on artifact authenticity and quality
- **Access Control**: Three-tier access system (public, restricted, private)
- **Category Management**: Organize artifacts by cultural categories
- **Reputation System**: Track contributions and build community trust
- **Verification Process**: Admin verification for curators and high-quality artifacts

## Usage

### Register as a Curator

```clarity
(contract-call? .Tradichain register-curator u"Dr. Maria Santos" "Mesoamerican History")
```

### Create a Category (Admin Only)

```clarity
(contract-call? .Tradichain create-category "oral-traditions")
```

### Submit Cultural Artifact

```clarity
(contract-call? .Tradichain submit-artifact 
  u"Creation Story of the Mountain People"
  u"Ancient creation myth passed down through generations about how the mountains were formed"
  u"sha256:abc123def456..."
  u"oral-traditions"
  u"Andes Mountains, Peru"
  u0)  ;; Public access
```

### Vote on Artifact

```clarity
(contract-call? .Tradichain vote-artifact u1 true)  ;; Upvote artifact ID 1
```

### Grant Access to Restricted Content

```clarity
(contract-call? .Tradichain grant-access u2 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## Access Levels

- **0**: Public - Anyone can view
- **1**: Restricted - Requires explicit access grant
- **2**: Private - Creator and admin only
- **3**: Sacred - Highest restriction level

## Read-Only Functions

- `get-artifact(artifact-id)` - Retrieve artifact details
- `get-curator(curator-id)` - Get curator information
- `has-access(artifact-id, accessor)` - Check access permissions
- `get-user-contributions(user)` - View user's contribution stats
- `get-contract-stats()` - Overall platform statistics

## Contract Administration

The contract owner can:
- Verify curators
- Verify artifacts (adds reputation bonus)
- Create new categories
- Pause/unpause the contract
- Grant access to restricted content

## Development

This contract is built for the Stacks blockchain using Clarity smart contract language.

### Testing with Clarinet

```bash
clarinet check
clarinet test
```

### Deployment

```bash
clarinet deploy --testnet
```

## Security Considerations

- Only verified curators can submit certain types of content
- Voting prevents self-voting on own artifacts
- Access controls protect sensitive cultural information
- Admin functions are owner-restricted
- Contract can be paused in emergencies

## Cultural Sensitivity

This platform respects indigenous rights and cultural protocols. Sensitive cultural information should use appropriate access levels, and communities retain control over their cultural data.
