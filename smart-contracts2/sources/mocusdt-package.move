#[allow(unused_use, duplicate_alias, unused_variable)]
module mockusdt::MockUSDT {
    use std::option;
    use iota::coin::{Self, Coin, TreasuryCap};
    use iota::transfer;
    use iota::tx_context::{Self, TxContext};
    use iota::object::{Self, UID};
    use iota::url;

    /// The one-time-witness for the coin
    public struct MOCKUSDT has drop {}

    /// Resource to store total minted amount
    public struct Supply has key, store {
        id: UID,
        total_minted: u64,
    }

    /// Initialize the MOCKUSDT coin
    fun init(witness: MOCKUSDT, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<MOCKUSDT>(
            witness,
            6, // decimals
            b"MUSDT", // symbol
            b"Mock USDT", // name
            b"Mock USDT for testing", // description
            option::none(), // icon url
            ctx
        );

        // Transfer the treasury cap to the publisher
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

        // Make the metadata object publicly available
        transfer::public_share_object(metadata);

        // Create supply object with 0 minted
        let supply = Supply { 
            id: object::new(ctx),
            total_minted: 0 
        };
        transfer::public_share_object(supply);
    }

    /// Mint new MOCKUSDT tokens
    public fun mint(
        treasury_cap: &mut TreasuryCap<MOCKUSDT>,
        supply: &mut Supply,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        
        // Update total minted
        supply.total_minted = supply.total_minted + amount;

        transfer::public_transfer(coin, recipient);
    }

    /// View total minted MOCKUSDT
    public fun total_minted(supply: &Supply): u64 {
        supply.total_minted
    }

    /// Transfer MOCKUSDT tokens
    public fun transfer_coin(
        coin: Coin<MOCKUSDT>,
        recipient: address
    ) {
        transfer::public_transfer(coin, recipient);
    }

    /// Get the value of a coin
    public fun value(coin: &Coin<MOCKUSDT>): u64 {
        coin::value(coin)
    }

    /// Split a coin into two coins
    public fun split(
        coin: &mut Coin<MOCKUSDT>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<MOCKUSDT> {
        coin::split(coin, amount, ctx)
    }

    /// Join two coins together
    public fun join(
        coin1: &mut Coin<MOCKUSDT>,
        coin2: Coin<MOCKUSDT>
    ) {
        coin::join(coin1, coin2);
    }

    /// Create a zero-value coin
    public fun zero(ctx: &mut TxContext): Coin<MOCKUSDT> {
        coin::zero<MOCKUSDT>(ctx)
    }

    /// Destroy a zero-value coin
    public fun destroy_zero(coin: Coin<MOCKUSDT>) {
        coin::destroy_zero(coin);
    }

    /// Mint tokens directly to sender (convenience function)
    public fun mint_to_sender(
        treasury_cap: &mut TreasuryCap<MOCKUSDT>,
        supply: &mut Supply,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<MOCKUSDT> {
        let coin = coin::mint(treasury_cap, amount, ctx);
        supply.total_minted = supply.total_minted + amount;
        coin
    }
}