#[allow(unused_use, duplicate_alias)]
module research::research {
    use std::string::String;
    use std::vector;
    use std::option;
    use std::address;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    use iota::coin::{Self, TreasuryCap, CoinMetadata};
    use iota::balance::Supply;

    /// --- Token for investor ownership ---
    public struct RESEARCH_SHARE has drop {}

    /// --- Research proposal metadata ---
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
        milestone_approvals: vector<bool>
    }

    /// --- Research project on-chain object ---
    public struct ResearchPaper has key {
        id: UID,
        metadata: ResearchMetadata,
        total_raised: u64,
        current_milestone: u64,
        is_revoked: bool
    }

    /// --- DAO vote record for proposal or milestone ---
    public struct VoteRecord has key {
        id: UID,
        yes_votes: u64,
        no_votes: u64,
        total_voters: u64
    }

    /// === INIT: Set up the token ===
    fun init(ctx: &mut TxContext) {
        let (treasury_cap, metadata) = 
            iota::coin::create_currency<RESEARCH_SHARE>(
                RESEARCH_SHARE {},
                6, // 6 decimals
                b"RSH",
                b"Research Share",
                b"Token representing ownership in a research proposal",
                option::none(),
                ctx
            );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    /// === Create a research proposal (Pre-research) ===
    public fun propose_research(
        title: String,
        description: String,
        problem_statement: String,
        methodology: String,
        milestones: vector<String>,
        funding_goal: u64,
        revenue_projection: u64,
        tags: vector<String>,
        ctx: &mut TxContext
    ) {
        let mut milestone_approvals = vector::empty<bool>();
        let len = vector::length(&milestones);
        let mut i = 0;
        while (i < len) {
            vector::push_back(&mut milestone_approvals, false);
            i = i + 1;
        };

        let metadata = ResearchMetadata {
            title,
            description,
            problem_statement,
            methodology,
            milestones,
            funding_goal,
            revenue_projection,
            researcher: tx_context::sender(ctx),
            tags,
            is_funded: false,
            dao_approved: false,
            milestone_approvals
        };

        let paper = ResearchPaper {
            id: object::new(ctx),
            metadata,
            total_raised: 0,
            current_milestone: 0,
            is_revoked: false
        };

        transfer::share_object(paper);
    }

    /// === Create a new vote record ===
    public fun create_vote_record(ctx: &mut TxContext) {
        let vote_record = VoteRecord {
            id: object::new(ctx),
            yes_votes: 0,
            no_votes: 0,
            total_voters: 0
        };
        transfer::share_object(vote_record);
    }

    /// === DAO Vote to approve the proposal ===
    public fun vote_on_proposal(
        vote_record: &mut VoteRecord,
        approve: bool
    ) {
        vote_record.total_voters = vote_record.total_voters + 1;
        if (approve) {
            vote_record.yes_votes = vote_record.yes_votes + 1;
        } else {
            vote_record.no_votes = vote_record.no_votes + 1;
        };
    }

    /// === Finalize the DAO decision (called by deployer/DAO) ===
    public fun finalize_proposal(
        paper: &mut ResearchPaper,
        vote_record: &VoteRecord
    ) {
        assert!(!paper.metadata.dao_approved, 100);
        if (vote_record.yes_votes > vote_record.total_voters / 2) {
            paper.metadata.dao_approved = true;
        };
    }

    /// === Investors invest in the proposal ===
    public fun invest(
        cap: &mut TreasuryCap<RESEARCH_SHARE>,
        amount: u64,
        paper: &mut ResearchPaper,
        investor: address,
        ctx: &mut TxContext
    ) {
        assert!(paper.metadata.dao_approved, 101);
        assert!(!paper.is_revoked, 102);

        let coins = iota::coin::mint(cap, amount, ctx);
        transfer::public_transfer(coins, investor);

        paper.total_raised = paper.total_raised + amount;

        if (paper.total_raised >= paper.metadata.funding_goal) {
            paper.metadata.is_funded = true;
        };
    }

    /// === DAO votes on milestone release ===
    public fun vote_on_milestone(
        vote_record: &mut VoteRecord,
        approve: bool
    ) {
        vote_record.total_voters = vote_record.total_voters + 1;
        if (approve) {
            vote_record.yes_votes = vote_record.yes_votes + 1;
        } else {
            vote_record.no_votes = vote_record.no_votes + 1;
        };
    }

    /// === Release funds for a milestone (called by DAO) ===
    public fun fund_milestone(
        paper: &mut ResearchPaper,
        vote_record: &VoteRecord
    ) {
        assert!(!paper.is_revoked, 103);

        if (vote_record.yes_votes > vote_record.total_voters / 2) {
            let index = paper.current_milestone;
            assert!(index < vector::length(&paper.metadata.milestone_approvals), 104);
            
            // Update milestone approval status
            let milestone_ref = vector::borrow_mut(&mut paper.metadata.milestone_approvals, index);
            *milestone_ref = true;
            
            // Advance to next milestone
            paper.current_milestone = index + 1;
        };
    }

    /// === DAO revokes funding for the paper ===
    public fun revoke_funding(paper: &mut ResearchPaper) {
        paper.is_revoked = true;
    }

    /// === Getter functions for reading contract state ===
    public fun get_paper_details(paper: &ResearchPaper): (String, u64, u64, bool) {
        (
            paper.metadata.title,
            paper.metadata.funding_goal,
            paper.total_raised,
            paper.metadata.is_funded
        )
    }
    
    public fun get_milestone_status(paper: &ResearchPaper, index: u64): bool {
        assert!(index < vector::length(&paper.metadata.milestone_approvals), 105);
        *vector::borrow(&paper.metadata.milestone_approvals, index)
    }
    
    public fun get_vote_results(vote_record: &VoteRecord): (u64, u64, u64) {
        (vote_record.yes_votes, vote_record.no_votes, vote_record.total_voters)
    }
}