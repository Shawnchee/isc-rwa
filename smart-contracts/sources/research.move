#[allow(unused_use, duplicate_alias)]
module research::research {
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};
    use std::address;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    // Use only what we need
    use iota::balance::{Self, Supply};
    use iota::coin::{Self};
    use iota::url::{Self, Url};
    use iota::event;

    /// --- NFT for research proposal ---
    public struct ResearchNFT has key, store {
        id: UID,
        title: String,
        description: String,
        researcher: address,
        image_url: Option<Url>,
        external_url: Option<Url>
    }

    /// --- Metadata for proposal ---
    public struct ResearchMetadata has store {
        title: String,
        description: String,
        problem_statement: String,
        methodology: String,
        milestones: vector<String>,
        funding_goal: u64,
        revenue_projection: u64,
        researcher: address,
        tags: vector<String>,
        is_funded: bool,
        dao_approved: bool,
        milestone_approvals: vector<bool>,
        image_url: Option<Url>,
        external_url: Option<Url>
    }

    /// --- Main Research object ---
    public struct ResearchPaper has key {
        id: UID,
        nft_id: address,
        metadata: ResearchMetadata,
        total_raised: u64,
        current_milestone: u64,
        is_revoked: bool,
        // Track investors and their shares
        investors: vector<address>,
        investments: vector<u64>
    }

    /// --- Investment record ---
    public struct InvestmentRecord has key, store {
        id: UID,
        paper_id: address,
        investor: address,
        amount: u64,
        percentage: u64  // Percentage of ownership * 10000 (e.g., 5% = 500)
    }

    public struct VoteRecord has key {
        id: UID,
        yes_votes: u64,
        no_votes: u64,
        total_voters: u64
    }

    public struct ResearchPaperMintedEvent has copy, drop {
        nft_id: address,
        paper_id: address,
        title: String,
        researcher: address
    }

    public struct InvestmentEvent has copy, drop {
        paper_id: address,
        amount: u64,
        investor: address,
        percentage: u64
    }

    // No need for init function - we're using native tokens

    /// === Mint NFT ===
    #[allow(lint(self_transfer))]
    public fun mint_research_nft(
        title: String,
        description: String,
        image_url: Option<Url>,
        external_url: Option<Url>,
        ctx: &mut TxContext
    ): address {
        let researcher = tx_context::sender(ctx);
        let nft = ResearchNFT {
            id: object::new(ctx),
            title,
            description,
            researcher,
            image_url,
            external_url
        };
        let nft_id = object::uid_to_address(&nft.id);
        transfer::public_transfer(nft, researcher);
        nft_id
    }

    /// === Propose Research ===
    public fun propose_research(
        title: String,
        description: String,
        problem_statement: String,
        methodology: String,
        milestones: vector<String>,
        funding_goal: u64,
        revenue_projection: u64,
        tags: vector<String>,
        image_url: Option<Url>,
        external_url: Option<Url>,
        ctx: &mut TxContext
    ) {
        let mut milestone_approvals = vector::empty<bool>();
        let len = vector::length(&milestones);
        let mut i = 0;
        while (i < len) {
            vector::push_back(&mut milestone_approvals, false);
            i = i + 1;
        };

        let researcher = tx_context::sender(ctx);
        
        // Store title for later use
        let paper_title = title;
        
        let metadata = ResearchMetadata {
            title,
            description,
            problem_statement,
            methodology,
            milestones,
            funding_goal,
            revenue_projection,
            researcher,
            tags,
            is_funded: false,
            dao_approved: false,
            milestone_approvals,
            image_url,
            external_url
        };

        let nft_id = mint_research_nft(paper_title, description, image_url, external_url, ctx);
        let paper_id = object::new(ctx);
        let paper_id_address = object::uid_to_address(&paper_id);
        
        let paper = ResearchPaper {
            id: paper_id,
            nft_id,
            metadata,
            total_raised: 0,
            current_milestone: 0,
            is_revoked: false,
            investors: vector::empty<address>(),
            investments: vector::empty<u64>()
        };

        event::emit(ResearchPaperMintedEvent {
            nft_id,
            paper_id: paper_id_address,
            title: paper_title,
            researcher
        });

        transfer::share_object(paper);
    }

    // This function uses native IOTA tokens directly
    public fun invest<CoinType: key + store>(
        paper: &mut ResearchPaper,
        payment: CoinType,  // Accept any coin type with key + store abilities
        amount: u64,   
        investor: address,
        ctx: &mut TxContext
    ) {
        assert!(paper.metadata.dao_approved, 100);
        assert!(!paper.is_revoked, 101);

        // Get the amount of tokens being invested
        assert!(amount > 0, 102);
        
        // Consume the payment (transfer to researcher)
        transfer::public_transfer(payment, paper.metadata.researcher);
        
        // Track the investment
        paper.total_raised = paper.total_raised + amount;

        // Calculate ownership percentage (as basis points, 1% = 100 points)
        let percentage = if (paper.metadata.funding_goal == 0) {
            0
        } else {
            (amount * 10000) / paper.metadata.funding_goal
        };
        
        
        // Track the investor and their investment
        vector::push_back(&mut paper.investors, investor);
        vector::push_back(&mut paper.investments, amount);
        
        // Create an investment record for the investor
        let record = InvestmentRecord {
            id: object::new(ctx),
            paper_id: object::uid_to_address(&paper.id),
            investor,
            amount,
            percentage
        };
        
        transfer::public_transfer(record, investor);
        
        // Check if funding goal is reached
        if (paper.total_raised >= paper.metadata.funding_goal) {
            paper.metadata.is_funded = true;
        };

        // Emit event
        event::emit(InvestmentEvent {
            paper_id: object::uid_to_address(&paper.id),
            amount,
            investor,
            percentage
        });
    }

    /// === Get Investor Shares ===
    public fun get_investor_share(
        paper: &ResearchPaper,
        investor: address
    ): (u64, u64) { // Returns (investment_amount, percentage)
        let len = vector::length(&paper.investors);
        let mut i = 0;
        let mut investment_amount = 0;
        
        // Find all investments by this investor
        while (i < len) {
            let current_investor = *vector::borrow(&paper.investors, i);
            if (current_investor == investor) {
                investment_amount = investment_amount + *vector::borrow(&paper.investments, i);
            };
            i = i + 1;
        };
        
        // Calculate percentage
        let percentage = if (paper.metadata.funding_goal == 0) {
            0
        } else {
            (investment_amount * 10000) / paper.metadata.funding_goal
        };
        
        (investment_amount, percentage)
    }

    /// === DAO Voting ===
    public fun vote_on_proposal(vote: &mut VoteRecord, approve: bool) {
        vote.total_voters = vote.total_voters + 1;
        if (approve) { 
            vote.yes_votes = vote.yes_votes + 1; 
        } else { 
            vote.no_votes = vote.no_votes + 1; 
        };
    }

    public fun finalize_proposal(paper: &mut ResearchPaper, vote: &VoteRecord) {
        assert!(!paper.metadata.dao_approved, 200);
        if (vote.yes_votes > vote.total_voters / 2) {
            paper.metadata.dao_approved = true;
        };
    }

    public fun revoke_funding(paper: &mut ResearchPaper) {
        paper.is_revoked = true;
    }

    public fun vote_on_milestone(vote: &mut VoteRecord, approve: bool) {
        vote.total_voters = vote.total_voters + 1;
        if (approve) { 
            vote.yes_votes = vote.yes_votes + 1; 
        } else { 
            vote.no_votes = vote.no_votes + 1; 
        };
    }

    public fun fund_milestone(paper: &mut ResearchPaper, vote: &VoteRecord) {
        assert!(!paper.is_revoked, 300);
        let idx = paper.current_milestone;
        if (vote.yes_votes > vote.total_voters / 2) {
            let m = vector::borrow_mut(&mut paper.metadata.milestone_approvals, idx);
            *m = true;
            paper.current_milestone = idx + 1;
        };
    }
}