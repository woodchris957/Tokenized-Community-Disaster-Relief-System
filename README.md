# Tokenized Community Disaster Relief System

A comprehensive blockchain-based disaster relief coordination system built on Stacks using Clarity smart contracts.

## Overview

This system provides a decentralized platform for coordinating disaster relief efforts through five interconnected smart contracts that manage different aspects of community recovery.

## Contracts

### 1. Damage Assessment Contract (\`damage-assessment.clar\`)
- Evaluates neighborhood impact and recovery needs
- Tracks damage reports and severity levels
- Manages assessment verification and scoring
- Issues damage assessment tokens for verified reports

### 2. Resource Coordination Contract (\`resource-coordination.clar\`)
- Manages volunteer efforts and supply distribution
- Coordinates resource allocation and tracking
- Handles volunteer registration and task assignment
- Distributes coordination tokens for participation

### 3. Insurance Assistance Contract (\`insurance-assistance.clar\`)
- Helps residents navigate claims and coverage issues
- Tracks insurance claim status and documentation
- Provides assistance request management
- Issues assistance tokens for completed help sessions

### 4. Temporary Housing Contract (\`temporary-housing.clar\`)
- Coordinates emergency shelter and relocation services
- Manages housing availability and assignments
- Tracks occupancy and housing needs
- Distributes housing tokens for shelter provision

### 5. Rebuilding Support Contract (\`rebuilding-support.clar\`)
- Facilitates construction coordination and contractor vetting
- Manages rebuilding project tracking
- Handles contractor verification and ratings
- Issues rebuilding tokens for completed projects

## Token Economics

Each contract issues its own utility tokens that represent participation and contribution to the relief effort:
- **DAMAGE** tokens: Earned by submitting verified damage assessments
- **RESOURCE** tokens: Earned by coordinating resources and volunteering
- **ASSIST** tokens: Earned by providing insurance assistance
- **SHELTER** tokens: Earned by providing temporary housing
- **REBUILD** tokens: Earned by supporting rebuilding efforts

## Key Features

- **Decentralized Coordination**: No single point of failure
- **Transparent Tracking**: All activities recorded on blockchain
- **Incentive Alignment**: Token rewards for community participation
- **Verification Systems**: Built-in validation for all activities
- **Community Governance**: Token holders can participate in decisions

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Stacks wallet for interaction

### Installation

\`\`\`bash
git clone <repository-url>
cd disaster-relief-contracts
npm install
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Usage Examples

### Submitting a Damage Assessment
\`\`\`clarity
(contract-call? .damage-assessment submit-assessment
"123 Main St"
u8
"Severe roof damage, flooding in basement")
\`\`\`

### Registering as a Volunteer
\`\`\`clarity
(contract-call? .resource-coordination register-volunteer
"John Doe"
"Medical assistance, debris removal")
\`\`\`

### Requesting Insurance Help
\`\`\`clarity
(contract-call? .insurance-assistance request-assistance
"Need help filing flood damage claim"
"home-insurance")
\`\`\`

## Contract Architecture

Each contract follows a similar pattern:
- **Data Storage**: Maps and variables for state management
- **Core Functions**: Primary business logic functions
- **Token Management**: Minting and transfer capabilities
- **Validation**: Input validation and error handling
- **Read Functions**: Public read-only functions for queries

## Security Considerations

- All functions include proper input validation
- Access controls prevent unauthorized modifications
- Token minting is controlled and auditable
- State changes are atomic and consistent

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details
