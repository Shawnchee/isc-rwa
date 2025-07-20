# ISC Research Work Tokenization (ISC-RWA)

## Overview of Smart Contracts

This project contains two smart contracts built on the IOTA blockchain using Move programming language:

1. ResearchToken (research.move)
2. MockUSDT (mocusdt-package.move)

## 1. ResearchToken (research.move)

A smart contract for tokenizing research papers, enabling investment in research projects through token-based funding.

### Core Components

#### Data Structures

- **RESEARCHTOKEN**: One-time witness type for token identification
- **ProjectInfo**: Comprehensive metadata storage including:
  - Basic information (title, abstract, category, domain)
  - Author details (name, affiliation, ORCID ID)
  - Funding parameters (goal, duration, stakeholder percentages)
  - Status tracking and revenue models
- **ResearchProposal**: Main object containing project info, token treasury capabilities

#### Key Functions

- **init**: Initializes the token ecosystem with 0 decimals and "RCLT" symbol
- **create_proposal**: Creates new research proposals with complete metadata
- **invest**: Enables investment in research projects with token distribution
- **Utility Functions**:
  - split_coin: Splits tokens for partial transfers
  - burn_token: Destroys unused tokens
  - Various getter functions for proposal information

### Business Logic

- Platform fee: Fixed 5% of all investments
- Researcher percentage: Configurable up to 95%
- Investor returns: 95% minus researcher percentage
- Token supply: Capped at the funding goal amount
- Tokens: Minted on-demand as investments are made

## 2. MockUSDT (mocusdt-package.move)

A stablecoin implementation to provide USDT-like functionality on the IOTA blockchain, maintained at a 1:1 peg with USD.

### Purpose

- Provides a stablecoin for the IOTA ecosystem (not natively supported)
- Maintained at a 1:1 peg with real USDT/USD
- Enables stable-value investments into research projects

### Implementation

- Standard coin functions (mint, transfer, burn)
- 1:1 backing mechanism
- Authorized minting controls
- Redemption functionality

## Integration Between Contracts

The platform leverages both contracts to create a complete research funding ecosystem:

1. MockUSDT provides the stable payment mechanism
2. ResearchToken creates the investment vehicle
3. Investors use MockUSDT to invest in research, receiving ResearchTokens

This dual-contract approach solves both the payment infrastructure needs and the research tokenization requirements for a decentralized research funding platform.