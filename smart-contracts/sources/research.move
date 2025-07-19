#[allow(unused_variable, duplicate_alias, unused_use, unused_field, unused_let_mut)]
module research_fund::ResearchToken {
    use std::option;
    use std::vector;
    use std::string;
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    use iota::coin::{Self, TreasuryCap, Coin};
    use iota::token::{Self, Token, TokenPolicy, TokenPolicyCap, ActionRequest};
    use iota::object::{Self, UID};

    /// One-Time Witness type (must match module name in uppercase)
    public struct RESEARCHTOKEN has drop {}

    /// Project metadata - removed UID fields that can't have 'drop'
    public struct ProjectInfo has store, drop {
        // Basic Information
        title: vector<u8>,
        abstract: vector<u8>,
        category: vector<u8>,
        domain: vector<u8>,
        tags: vector<vector<u8>>,
        technical_approach: vector<u8>,
        project_image: vector<u8>,

        // Author Information
        author_name: vector<u8>,
        author_affiliation: vector<u8>,
        author_image: vector<u8>,
        orcid_id: vector<u8>,

        // Funding Details
        funding_goal: u64,
        campaign_duration_days: u64,
        platform_percentage: u64,  // Fixed at 5%
        research_team_percentage: u64,
        investor_percentage: u64,
        total_invested: u64,

        // Returns/Royalties
        revenue_models: vector<vector<u8>>,

        // Status
        creation_timestamp: u64,
        status: vector<u8>  // "ACTIVE", "COMPLETED", etc.
    }

    /// Research proposal object with proper key ability
    public struct ResearchProposal has key {
        id: UID,
        info: ProjectInfo,
        treasury_cap: TreasuryCap<RESEARCHTOKEN>,
        policy_cap: TokenPolicyCap<RESEARCHTOKEN>
    }

    /// Fixed init function with correct witness type and simplified parameters
    fun init(witness: RESEARCHTOKEN, ctx: &mut TxContext) {
        // Create a closed-loop token with 0 decimals
        let (treasury_cap, metadata) = coin::create_currency<RESEARCHTOKEN>(
            witness,
            0,
            b"RCLT",
            b"Research CLT",
            b"Research Proposal CLT",
            option::none(), 
            ctx
        );

        // Create policy
        let (policy, policy_cap) = token::new_policy(&treasury_cap, ctx);

        // Share token policy and freeze metadata
        token::share_policy(policy);
        transfer::public_freeze_object(metadata);

        // Transfer caps to creator (researcher)
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_transfer(policy_cap, tx_context::sender(ctx));
    }

    #[allow(lint(self_transfer))]
    public fun create_proposal(
        title: vector<u8>,
        abstract: vector<u8>,
        category: vector<u8>,
        domain: vector<u8>,
        tags: vector<vector<u8>>,
        technical_approach: vector<u8>,
        project_image: vector<u8>,
        author_name: vector<u8>,
        author_affiliation: vector<u8>,
        author_image: vector<u8>,
        orcid_id: vector<u8>,
        funding_goal: u64,
        campaign_duration_days: u64,
        research_team_percentage: u64,
        revenue_models: vector<vector<u8>>,
        mut treasury_cap: TreasuryCap<RESEARCHTOKEN>,
        policy_cap: TokenPolicyCap<RESEARCHTOKEN>,
        ctx: &mut TxContext
    ) {
        // Validate percentages
        assert!(research_team_percentage <= 95, 1); // Platform takes 5%

        let info = ProjectInfo {
            title,
            abstract,
            category,
            domain,
            tags,
            technical_approach,
            project_image,
            author_name,
            author_affiliation,
            author_image,
            orcid_id,
            funding_goal,
            campaign_duration_days,
            platform_percentage: 5,  // Fixed
            research_team_percentage,
            investor_percentage: 95 - research_team_percentage,
            total_invested: 0,
            revenue_models,
            creation_timestamp: tx_context::epoch_timestamp_ms(ctx),
            status: b"ACTIVE"
        };

        // Create proposal
        let mut proposal = ResearchProposal {
            id: object::new(ctx),
            info,
            treasury_cap,
            policy_cap
        };

        // Mint initial tokens
        let initial_supply = funding_goal;
        let tokens = coin::mint(&mut proposal.treasury_cap, initial_supply, ctx);

        // Share proposal and transfer tokens
        transfer::share_object(proposal);
        transfer::public_transfer(tokens, tx_context::sender(ctx));
    }

    /// Investors receive tokens based on their contribution
    public fun invest(
        proposal: &mut ResearchProposal,
        amount_in_myr: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(&mut proposal.treasury_cap, amount_in_myr, ctx);
        proposal.info.total_invested = proposal.info.total_invested + amount_in_myr;
        transfer::public_transfer(coin, recipient);
    }

    /// Helper to split token for partial investments
    public fun split_coin(
        coin: &mut Coin<RESEARCHTOKEN>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<RESEARCHTOKEN> {
        coin::split(coin, amount, ctx)
    }

    /// Destroy token (optional logic to let researcher burn leftover tokens)
    public fun burn_token(coin: Coin<RESEARCHTOKEN>) {
        coin::destroy_zero(coin);
    }

    /// Query balance or value
    public fun token_value(coin: &Coin<RESEARCHTOKEN>): u64 {
        coin::value(coin)
    }

    /// Get proposal info
    public fun get_proposal_info(proposal: &ResearchProposal): &ProjectInfo {
        &proposal.info
    }

    /// Get funding goal
    public fun get_funding_goal(proposal: &ResearchProposal): u64 {
        proposal.info.funding_goal
    }

    /// Get total invested
    public fun get_total_invested(proposal: &ResearchProposal): u64 {
        proposal.info.total_invested
    }
}