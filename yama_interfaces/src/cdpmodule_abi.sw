library cdpmodule_abi;

use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;

pub struct Vault {
    collateral_amount: u64,
    collateral_type_id: u64,
    owner: Identity,
    alt_owner: Option<Identity>,
    initial_debt: UFP128,
    is_liquidated: bool
}

pub struct CollateralType {
    token: b256,
    price_source: b256,
    debt_floor: UFP128,
    debt_ceiling: UFP128,
    collateral_ratio: UFP128,
    interest_rate: UFP128,  // Debt is multiplied by this value every second
    total_collateral: u64,
    last_update_time: u64,
    initial_debt: UFP128,
    cumulative_interest: UFP128,
    borrowing_enabled: bool,
    allowlist_enabled: bool
}

abi CDPModule {
    // Borrow money from a vault
    #[storage(read, write)]
    fn borrow(vault_id: u64, amount: u64);

    // Repay a debt with YSS
    #[payable]
    #[storage(read, write)]
    fn repay(vault_id: u64);

    // Adds more collateral to a vault
    #[payable]
    #[storage(read, write)]
    fn add_collateral(vault_id: u64);

    // Removes collateral from a vault. Panics if this makes the vault
    // undercollateralized
    #[storage(read, write)]
    fn remove_collateral(vault_id: u64, amount: u64);

    // Creates a new vault and borrows loan_amount YSS
    // Returns the vault ID
    #[payable]
    #[storage(read, write)]
    fn create_vault(collateral_type_id: u64, alt_owner: Option<Identity>) -> u64;

    // Liquidates an undercollateralized vault that hasn't been liquidated yet
    #[storage(read, write)]
    fn liquidate(vault_id: u64);

    // Used by allowed contracts to transfer tokens out
    #[storage(read)]
    fn transfer(token: ContractId, to: Identity, amount: u64);

    // Used by the liquidator contract to write off liquidated vaults
    #[storage(read, write)]
    fn clear_vault(vault_id: u64);
    
    // Sets the liquidator for this module
    #[storage(read, write)]
    fn set_liquidator(contract_id: b256);
    
    // Used to disable/enable borrowing
    #[storage(read, write)]
    fn set_borrowing_disabled(value: bool);

    // Sets allowed borrowers for a particular collateral type if it uses an
    // allowlist
    #[storage(read, write)]
    fn set_allowed_borrower(collateral_type_id: u64, borrower: Identity,
        is_allowed: bool);
    
    // Sets the collateral manager
    #[storage(read, write)]
    fn set_collateral_manager(contract_id: b256);

    // Used by allowed contracts to create new collateral types
    // Returns the collateral type ID
    #[storage(read, write)]
    fn add_collateral_type(
        token: b256,
        price_source: b256,
        debt_floor: UFP128,
        debt_ceiling: UFP128,
        collateral_ratio: UFP128,
        interest_rate: UFP128,
        borrowing_enabled: bool,
        allowlist_enabled: bool
    ) -> u64;

    // Used by allowed contracts to set the parameters of a collateral type
    #[storage(read, write)]
    fn set_collateral_type_params(
        collateral_type_id: u64,
        price_source: b256,
        debt_floor: UFP128,
        debt_ceiling: UFP128,
        collateral_ratio: UFP128,
        interest_rate: UFP128,
        borrowing_enabled: bool,
        allowlist_enabled: bool
    );

    // Gets the collateral manager contract
    #[storage(read)]
    fn get_collateral_manager() -> b256;

    // Gets the liquidator contract
    #[storage(read)]
    fn get_liquidator() -> b256;

    // Gets the stablecoin contract
    #[storage(read)]
    fn get_stablecoin() -> b256;

    // Gets the balance sheet contract
    #[storage(read)]
    fn get_balance_sheet() -> b256;

    #[storage(read)]
    fn get_entered() -> bool;

    // Determines if a vault has been liquidated
    #[storage(read)]
    fn is_liquidated(vault_id: u64) -> bool;

    // Gets the debt of a vault; don't forget to call update_interest() before
    // this
    #[storage(read)]
    fn get_debt(vault_id: u64) -> u64;

    #[storage(read)]
    fn get_owner(vault_id: u64) -> Identity;

    #[storage(read)]
    fn get_alt_owner(vault_id: u64) -> Option<Identity>;

    // Gets the total debt of a collateral type
    #[storage(read)]
    fn get_total_debt(collateral_type_id: u64) -> u64;

    // Gets the collateralization ratio of a collateral type
    #[storage(read)]
    fn get_collateral_ratio(collateral_type_id: u64) -> UFP128;

    // Gets the debt floor of a collateral type
    #[storage(read)]
    fn get_debt_floor(collateral_type_id: u64) -> UFP128;

    // Gets the debt ceiling of a collateral type
    #[storage(read)]
    fn get_debt_ceiling(collateral_type_id: u64) -> UFP128;

    // Updates the interest for a collateral type
    #[storage(read, write)]
    fn update_interest(collateral_type_id: u64);

    // Gets the collateral type ID of a vault
    #[storage(read)]
    fn get_collateral_type_id(vault_id: u64) -> u64;

    // Gets the collateral token for a specific vault
    #[storage(read)]
    fn get_collateral_token(vault_id: u64) -> ContractId;

    // Gets the amount of collateral in a specific vault
    #[storage(read)]
    fn get_collateral_amount(vault_id: u64) -> u64;

    // Gets the unit price of a vault's collateral
    #[storage(read)]
    fn get_collateral_price(vault_id: u64) -> UFP128;

    // Gets the value of a vault's collateral
    #[storage(read)]
    fn get_collateral_value(vault_id: u64) -> u64;

    // Multiplies the debt by the collateral ratio for a vault
    #[storage(read)]
    fn get_target_collateral_value(vault_id: u64) -> u64;

    // Determines if a vault is undercollateralized
    #[storage(read)]
    fn is_undercollateralized(vault_id: u64) -> bool;

    // Gets a vault
    #[storage(read)]
    fn get_vault(vault_id: u64) -> Vault;

    // Gets annual interest, assumes 31536000 seconds in a year
    #[storage(read)]
    fn get_annual_interest(collateral_type_id: u64) -> UFP128;

    // Gets per-second interest
    #[storage(read)]
    fn get_ps_interest(collateral_type_id: u64) -> UFP128;

    // Gets a collateral type
    #[storage(read)]
    fn get_collateral_type(collateral_type_id: u64) -> CollateralType;

    // Gets a collateral type of a specific vault
    #[storage(read)]
    fn get_collateral_type_of(vault_id: u64) -> CollateralType;

    // Checks if borrowing is disabled for this module
    #[storage(read)]
    fn get_borrowing_disabled() -> bool;

    // Sets the balancesheet module
    #[storage(read, write)]
    fn set_balancesheet_module(value: b256);

    // Checks if a borrower is allowed to borrow from a collateral type
    #[storage(read)]
    fn is_allowed_borrower(collateral_type_id: u64, borrower: Identity) -> bool;
}