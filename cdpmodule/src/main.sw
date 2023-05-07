contract;

use yama_interfaces::{
    cdpmodule_abi::{
        CDPModule,
        Vault,
        CollateralType
    },
    errors::CDPError,
    events::{
        SetDebt,
        Borrow,
        Repay,
        AddCollateral,
        RemoveCollateral,
        CreateVault,
        Liquidate,
        AddCollateralType,
        SetCollateralType,
        UpdateInterest,
        ClearVault
    },
    pricesource_abi::PriceSource,
    collateralmanager_abi::CollateralManager,
    liquidator_abi::Liquidator
};
use std::{
    storage::StorageVec,
    block::timestamp,
    context::msg_amount,
    token::transfer,
    logging::log
};
use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;
use stablecoin_library::{
    helpers::{
        sender_id,
        verify_sender_allowed,
        verify_tokens_from,
        mint,
        burn,
        add_surplus,
        tokens_to_fp,
        fp_to_tokens,
        fp_to_i256_tokens,
        safe_unwrap_bool,
    },
    constants::{
        ZERO_B256,
        SECONDS_IN_YEAR
    }
};
use signed_integers::i256::I256;

storage {
    collateral_manager: b256 = ZERO_B256,
    liquidator: b256 = ZERO_B256,
    stablecoin_contract: b256 = ZERO_B256,
    balancesheet_module: b256 = ZERO_B256,
    borrowing_disabled: bool = false,
    vaults: StorageVec<Vault> = StorageVec{},
    collateral_types: StorageVec<CollateralType> = StorageVec{},

    // (vault_id, account) => is_allowed
    allowed_borrowers: StorageMap<(u64, Identity), bool> = StorageMap{},
    entered: bool = false
}

impl CDPModule for Contract {
    #[storage(read, write)]
    fn borrow(vault_id: u64, amount: u64) {
        borrow(vault_id, amount);
    }

    #[payable]
    #[storage(read, write)]
    fn repay(vault_id: u64) {
        verify_tokens_from(storage.stablecoin_contract);
        verify_vault_owner(vault_id);
        verify_not_liquidated(vault_id);
        update_interest(get_vault(vault_id).collateral_type_id);
        let debt: UFP128 = get_debt(vault_id);
        require(msg_amount() <= fp_to_tokens(debt),
            CDPError::RepayOverpayment);
        let new_debt: UFP128
            = debt - tokens_to_fp(msg_amount());
        require_valid_debt_amount(vault_id, new_debt);
        burn(msg_amount(), storage.stablecoin_contract);
        set_debt(vault_id, new_debt);

        log(Repay {
            account: sender_id(),
            vault_id: vault_id,
            amount: msg_amount()
        });
    }

    #[payable]
    #[storage(read, write)]
    fn add_collateral(vault_id: u64) {
        add_collateral(vault_id);
    }

    #[storage(read, write)]
    fn remove_collateral(vault_id: u64, amount: u64) {
        require(!storage.entered, CDPError::Reentrancy);
        storage.entered = true;
        verify_vault_owner(vault_id);
        verify_not_liquidated(vault_id);
        
        update_interest(get_vault(vault_id).collateral_type_id);

        let collateral_manager = abi(CollateralManager,
            storage.collateral_manager);
        collateral_manager.handle_collateral_withdrawal(vault_id, amount);

        let mut vault: Vault = get_vault(vault_id);
        let mut c_type: CollateralType = get_collateral_type_of(vault_id);

        vault.collateral_amount -= amount;
        c_type.total_collateral -= amount;

        storage.vaults.set(vault_id, vault);
        storage.collateral_types.set(vault.collateral_type_id, c_type);

        require(!is_undercollateralized(vault_id),
            CDPError::Undercollateralized);

        transfer(
            amount,
            ContractId::from(c_type.token),
            sender_id()
        );

        log(RemoveCollateral {
            account: sender_id(),
            vault_id: vault_id,
            amount: amount
        });
        storage.entered = false;
    }

    #[payable]
    #[storage(read, write)]
    fn create_vault(collateral_type_id: u64, alt_owner: Option<Identity>) -> u64 {
        let vault: Vault = Vault {
            collateral_amount: 0,
            collateral_type_id: collateral_type_id,
            owner: sender_id(),
            alt_owner: alt_owner,
            initial_debt: UFP128::zero(),
            is_liquidated: false
        };
        storage.vaults.push(vault);
        let vault_id: u64 = storage.vaults.len() - 1;
        add_collateral(vault_id);

        log(CreateVault {
            owner: sender_id(),
            alt_owner: alt_owner,
            vault_id: vault_id,
            collateral_type_id: collateral_type_id,
            collateral_amount: msg_amount()
        });

        vault_id
    }

    #[storage(read, write)]
    fn liquidate(vault_id: u64) {
        verify_not_liquidated(vault_id);
        require(is_undercollateralized(vault_id),
            CDPError::NotUndercollateralized);
        let mut vault: Vault = get_vault(vault_id);
        vault.is_liquidated = true;
        storage.vaults.set(vault_id, vault);
        update_interest(vault.collateral_type_id);
        let liquidator = abi(Liquidator, storage.liquidator);
        liquidator.liquidate(vault_id);

        log(Liquidate {
            initiator: sender_id(),
            liquidated: vault.owner,
            vault_id: vault_id
        });
    }

    #[storage(read)]
    fn transfer(token: ContractId, to: Identity, amount: u64) {
        verify_sender_allowed(storage.stablecoin_contract);
        if amount > 0 {
            transfer(amount, token, to);
        }
    }

    #[storage(read, write)]
    fn clear_vault(vault_id: u64) {
        verify_sender_allowed(storage.stablecoin_contract);
        update_interest(get_vault(vault_id).collateral_type_id);
        let mut vault: Vault = get_vault(vault_id);
        let mut c_type: CollateralType = get_collateral_type_of(vault_id);
        c_type.total_collateral -= vault.collateral_amount;
        let collateral_manager = abi(CollateralManager,
            storage.collateral_manager);
        collateral_manager.handle_collateral_withdrawal(vault_id, vault.collateral_amount);
        vault.collateral_amount = 0;
        storage.collateral_types.set(vault.collateral_type_id, c_type);
        storage.vaults.set(vault_id, vault);
        
        set_debt(vault_id, UFP128::zero());
        log(ClearVault {
            account: sender_id(),
            vault_id: vault_id
        });
    }

    #[storage(read, write)]
    fn set_liquidator(contract_id: b256) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.liquidator = contract_id;
    }

    #[storage(read, write)]
    fn set_borrowing_disabled(value: bool) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.borrowing_disabled = value;
    }

    #[storage(read, write)]
    fn set_allowed_borrower(
        collateral_type_id: u64,
        borrower: Identity,
        is_allowed: bool
    ) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.allowed_borrowers.insert((collateral_type_id, borrower),
            is_allowed);
    }

    #[storage(read, write)]
    fn set_collateral_manager(contract_id: b256) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.collateral_manager = contract_id;
    }

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
    ) -> u64 {
        verify_sender_allowed(storage.stablecoin_contract);
        let c_type: CollateralType = CollateralType {
            token: token,
            price_source: price_source,
            debt_floor: debt_floor,
            debt_ceiling: debt_ceiling,
            collateral_ratio: collateral_ratio,
            interest_rate: interest_rate,
            total_collateral: 0,
            last_update_time: timestamp(),
            initial_debt: UFP128::zero(),
            cumulative_interest: UFP128::from_u64(1),
            borrowing_enabled: borrowing_enabled,
            allowlist_enabled: allowlist_enabled
        };

        storage.collateral_types.push(c_type);

        let collateral_type_id: u64 = storage.collateral_types.len() - 1;
        log(AddCollateralType {
            collateral_type_id: collateral_type_id,
            token: token,
            price_source: price_source,
            debt_floor: debt_floor,
            debt_ceiling: debt_ceiling,
            collateral_ratio: collateral_ratio,
            interest_rate: interest_rate,
            borrowing_enabled: borrowing_enabled,
            allowlist_enabled: allowlist_enabled
        });

        collateral_type_id
    }

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
    ) {
        verify_sender_allowed(storage.stablecoin_contract);
        let mut c_type: CollateralType = get_collateral_type(
            collateral_type_id);
        
        c_type.price_source = price_source;
        c_type.debt_floor = debt_floor;
        c_type.debt_ceiling = debt_ceiling;
        c_type.collateral_ratio = collateral_ratio;
        c_type.interest_rate = interest_rate;
        c_type.borrowing_enabled = borrowing_enabled;
        c_type.allowlist_enabled = allowlist_enabled;

        storage.collateral_types.set(collateral_type_id, c_type);

        log(SetCollateralType {
            collateral_type_id: collateral_type_id,
            token: c_type.token,
            price_source: price_source,
            debt_floor: debt_floor,
            debt_ceiling: debt_ceiling,
            collateral_ratio: collateral_ratio,
            interest_rate: interest_rate,
            borrowing_enabled: borrowing_enabled,
            allowlist_enabled: allowlist_enabled
        });
    }

    #[storage(read)]
    fn is_liquidated(vault_id: u64) -> bool {
        get_vault(vault_id).is_liquidated
    }

    #[storage(read)]
    fn get_owner(vault_id: u64) -> Identity {
        get_vault(vault_id).owner
    }

    #[storage(read)]
    fn get_alt_owner(vault_id: u64) -> Option<Identity> {
        get_vault(vault_id).alt_owner
    }

    #[storage(read)]
    fn get_debt(vault_id: u64) -> u64 {
        fp_to_tokens(get_debt(vault_id))
    }

    #[storage(read)]
    fn get_total_debt(collateral_type_id: u64) -> u64 {
        fp_to_tokens(get_total_debt(collateral_type_id))
    }

    #[storage(read)]
    fn get_collateral_ratio(collateral_type_id: u64) -> UFP128 {
        get_collateral_type(collateral_type_id).collateral_ratio
    }

    #[storage(read)]
    fn get_debt_ceiling(collateral_type_id: u64) -> UFP128 {
        get_collateral_type(collateral_type_id).debt_ceiling
    }

    #[storage(read)]
    fn get_debt_floor(collateral_type_id: u64) -> UFP128 {
        get_collateral_type(collateral_type_id).debt_floor
    }

    #[storage(read, write)]
    fn update_interest(collateral_type_id: u64) {
        update_interest(collateral_type_id);
    }

    #[storage(read)]
    fn get_collateral_manager() -> b256 {
        storage.collateral_manager
    }

    #[storage(read)]
    fn get_liquidator() -> b256 {
        storage.liquidator
    }

    #[storage(read)]
    fn get_stablecoin() -> b256 {
        storage.stablecoin_contract
    }

    #[storage(read)]
    fn get_balance_sheet() -> b256 {
        storage.balancesheet_module
    }

    #[storage(read)]
    fn get_entered() -> bool {
        storage.entered
    }

    #[storage(read)]
    fn get_collateral_type_id(vault_id: u64) -> u64 {
        get_vault(vault_id).collateral_type_id
    }

    #[storage(read)]
    fn get_collateral_token(vault_id: u64) -> ContractId {
        ContractId::from(get_collateral_type_of(vault_id).token)
    }

    #[storage(read)]
    fn get_collateral_amount(vault_id: u64) -> u64 {
        get_collateral_amount(vault_id)
    }

    #[storage(read)]
    fn get_collateral_price(vault_id: u64) -> UFP128 {
        get_collateral_price(vault_id)
    }

    #[storage(read)]
    fn get_collateral_value(vault_id: u64) -> u64 {
        fp_to_tokens(get_collateral_value(vault_id))
    }

    #[storage(read)]
    fn get_target_collateral_value(vault_id: u64) -> u64 {
        fp_to_tokens(get_target_collateral_value(vault_id))
    }

    #[storage(read)]
    fn is_undercollateralized(vault_id: u64) -> bool {
        is_undercollateralized(vault_id)
    }

    #[storage(read)]
    fn get_vault(vault_id: u64) -> Vault {
        get_vault(vault_id)
    }

    #[storage(read)]
    fn get_annual_interest(collateral_type_id: u64) -> UFP128 {
        get_collateral_type(collateral_type_id).interest_rate.powu(
            SECONDS_IN_YEAR)
    }

    #[storage(read)]
    fn get_ps_interest(collateral_type_id: u64) -> UFP128 {
        get_collateral_type(collateral_type_id).interest_rate
    }

    #[storage(read)]
    fn get_collateral_type(collateral_type_id: u64) -> CollateralType {
        get_collateral_type(collateral_type_id)
    }

    #[storage(read)]
    fn get_collateral_type_of(vault_id: u64) -> CollateralType {
        get_collateral_type_of(vault_id)
    }

    #[storage(read)]
    fn get_borrowing_disabled() -> bool {
        storage.borrowing_disabled
    }

    #[storage(read, write)]
    fn set_balancesheet_module(value: b256) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.balancesheet_module = value;
    }

    #[storage(read)]
    fn is_allowed_borrower(collateral_type_id: u64, borrower: Identity) -> bool {
        safe_unwrap_bool(
            storage.allowed_borrowers.get((collateral_type_id, borrower)))
    }
}

#[storage(read, write)]
fn borrow(vault_id: u64, amount: u64) {
    verify_vault_owner(vault_id);
    verify_not_liquidated(vault_id);
    require(!storage.borrowing_disabled, CDPError::BorrowingDisabled);
    let vault: Vault = get_vault(vault_id);
    let c_type_id: u64 = vault.collateral_type_id;
    let c_type: CollateralType = get_collateral_type_of(vault_id);
    require(c_type.borrowing_enabled,
        CDPError::CollateralTypeBorrowingDisabled);
    if (c_type.allowlist_enabled) {
        require(
            safe_unwrap_bool(storage.allowed_borrowers.get((c_type_id, sender_id()))),
            CDPError::BorrowerNotAllowed
        );
    }
    update_interest(c_type_id);
    let new_debt: UFP128 = get_debt(vault_id) + tokens_to_fp(amount);
    require_valid_debt_amount(vault_id, new_debt);
    set_debt(vault_id, new_debt);

    require(get_total_debt(c_type_id).le(c_type.debt_ceiling),
        CDPError::ExceedsDebtCeiling);
    mint(amount, sender_id(), storage.stablecoin_contract);

    log(Borrow {
        account: sender_id(),
        vault_id: vault_id,
        amount: amount
    });
}

#[storage(read, write)]
fn add_collateral(vault_id: u64) {
    require(!storage.entered, CDPError::Reentrancy);
    storage.entered = true;
    verify_tokens_from(get_collateral_type_of(vault_id).token);
    verify_vault_owner(vault_id);
    verify_not_liquidated(vault_id);

    let mut vault: Vault = get_vault(vault_id);
    let mut c_type: CollateralType = get_collateral_type_of(vault_id);

    vault.collateral_amount += msg_amount();
    c_type.total_collateral += msg_amount();

    storage.vaults.set(vault_id, vault);
    storage.collateral_types.set(vault.collateral_type_id, c_type);

    let collateral_manager = abi(CollateralManager,
        storage.collateral_manager);
    collateral_manager.handle_collateral_deposit(vault_id, msg_amount());

    log(AddCollateral {
        account: sender_id(),
        vault_id: vault_id,
        amount: msg_amount()
    });
    storage.entered = false;
}

#[storage(read)]
fn verify_vault_owner(vault_id: u64) {
    let vault = get_vault(vault_id);
    if vault.alt_owner.is_some() {
        require(
            sender_id() == vault.owner ||
            sender_id() == vault.alt_owner.unwrap(),
            CDPError::NotVaultOwner
        );
    } else {
        require(
            sender_id() == vault.owner,
            CDPError::NotVaultOwner
        );
    }
}

#[storage(read)]
fn verify_not_liquidated(vault_id: u64) {
    require(!get_vault(vault_id).is_liquidated, CDPError::Liquidated);
}

#[storage(read)]
fn get_collateral_type(collateral_type_id: u64) -> CollateralType {
    storage.collateral_types.get(collateral_type_id).unwrap()
}

#[storage(read)]
fn get_collateral_type_of(vault_id: u64) -> CollateralType {
    get_collateral_type(get_vault(vault_id).collateral_type_id)
}

#[storage(read)]
fn get_vault(vault_id: u64) -> Vault {
    storage.vaults.get(vault_id).unwrap()
}

#[storage(read)]
fn get_debt(vault_id: u64) -> UFP128 {
    get_vault(vault_id).initial_debt
        * get_collateral_type_of(vault_id).cumulative_interest
}

#[storage(read)]
fn get_total_debt(collateral_type_id: u64) -> UFP128 {
    let c_type: CollateralType = get_collateral_type(collateral_type_id);

    c_type.initial_debt * c_type.cumulative_interest
}

#[storage(read, write)]
fn update_interest(collateral_type_id: u64) {
    let mut c_type: CollateralType = get_collateral_type(collateral_type_id);

    let time_delta: u64 = timestamp() - c_type.last_update_time;

    if (time_delta == 0) {
        return;
    }

    let old_total_debt: I256 = fp_to_i256_tokens(
        get_total_debt(collateral_type_id));
    c_type.cumulative_interest *= c_type.interest_rate.powu(time_delta);

    log(UpdateInterest {
        collateral_type_id: collateral_type_id,
        interest_rate: c_type.interest_rate,
        last_update_time: c_type.last_update_time,
        cumulative_interest: c_type.cumulative_interest
    });

    c_type.last_update_time = timestamp();

    storage.collateral_types.set(collateral_type_id, c_type);

    add_surplus(fp_to_i256_tokens(get_total_debt(collateral_type_id))
        - old_total_debt, storage.balancesheet_module);
}

#[storage(read)]
fn get_collateral_price(vault_id: u64) -> UFP128 {
    let price_source = abi(
        PriceSource,
        get_collateral_type_of(vault_id).price_source
    );
    price_source.price()
}

#[storage(read)]
fn get_collateral_amount(vault_id: u64) -> u64 {
    get_vault(vault_id).collateral_amount
}

#[storage(read)]
fn get_collateral_amount_fp(vault_id: u64) -> UFP128 {
    tokens_to_fp(get_collateral_amount(vault_id))
}

#[storage(read)]
fn get_collateral_value(vault_id: u64) -> UFP128 {
    get_collateral_amount_fp(vault_id) * get_collateral_price(vault_id)
}

#[storage(read)]
fn get_target_collateral_value(vault_id: u64) -> UFP128 {
    get_debt(vault_id) * get_collateral_type_of(vault_id).collateral_ratio
}

#[storage(read)]
fn is_undercollateralized(vault_id: u64) -> bool {
    get_collateral_value(vault_id) < get_target_collateral_value(vault_id)
}

#[storage(read)]
fn valid_debt_amount(vault_id: u64, amount: UFP128) -> bool {
    amount == UFP128::zero()
        || (amount.ge(get_collateral_type_of(vault_id).debt_floor)
            && get_collateral_value(vault_id).ge(amount * get_collateral_type_of(vault_id).collateral_ratio))
}

#[storage(read)]
fn require_valid_debt_amount(vault_id: u64, amount: UFP128) {
    require(valid_debt_amount(vault_id, amount), CDPError::InvalidDebtAmount);
}

#[storage(read, write)]
fn set_debt(vault_id: u64, new_debt: UFP128) {
    let mut c_type: CollateralType = get_collateral_type_of(vault_id);
    let mut vault: Vault = get_vault(vault_id);
    let old_initial_debt: UFP128 = vault.initial_debt;
    let new_initial_debt: UFP128 = new_debt / c_type.cumulative_interest;
    
    vault.initial_debt = new_initial_debt;
    storage.vaults.set(vault_id, vault);

    c_type.initial_debt
        = c_type.initial_debt + new_initial_debt - old_initial_debt;
    storage.collateral_types.set(vault.collateral_type_id, c_type);

    log(SetDebt {
        account: sender_id(),
        vault_id: vault_id,
        debt: new_debt,
        initial_debt: new_initial_debt
    });
}