use core::clone::Clone;
use core::traits::TryInto;
use starknet::{
    ContractAddress, contract_address_const, get_block_timestamp, contract_address_to_felt252
};
use snforge_std::{
    declare, ContractClassTrait, test_address, spy_events, SpyOn, EventSpy, EventAssertions
};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::token::erc721::ERC721Component;
use cairo_erc_7498::erc7498::interface::{
    IERC7498_ID, BURN_ADDRESS, ItemType, OfferItem, ConsiderationItem, CampaignRequirements,
    CampaignParams, IERC7498, IERC7498Dispatcher, IERC7498DispatcherTrait
};
use cairo_erc_7498::erc7498::erc7498::ERC7498Component;
use cairo_erc_7498::presets::erc721_redeemables::{
    ERC721Redeemables, IERC721RedeemablesMixinDispatcherTrait, IERC721RedeemablesMixinDispatcher,
    IERC721RedeemablesMixinSafeDispatcherTrait, IERC721RedeemablesMixinSafeDispatcher
};
use cairo_erc_7498::presets::erc721_redemption::{
    IERC721RedemptionMintable, ERC721RedemptionMintable,
    IERC721RedemptionMintableMixinDispatcherTrait, IERC721RedemptionMintableMixinDispatcher,
    IERC721RedemptionMintableMixinSafeDispatcherTrait, IERC721RedemptionMintableMixinSafeDispatcher
};
use snforge_std::{start_prank, stop_prank, CheatTarget};

const TOKEN_ID: u256 = 2;
const CAMPAIGN_ID: u256 = 1;
const INVALID_TOKEN_ID: u256 = TOKEN_ID + 1;

fn NAME() -> ByteArray {
    "ERC721Redeemables"
}

fn SYMBOL() -> ByteArray {
    "ERC721RDM"
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn ACCOUNT1() -> ContractAddress {
    contract_address_const::<'ACCOUNT1'>()
}

fn BASE_URI() -> ByteArray {
    "https://example.com"
}

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn CAMPAIGN_URI() -> ByteArray {
    "https://example.com/campaign"
}

fn CAMPAIGN_URI_NEW() -> ByteArray {
    "https://example.com/new/campaign"
}

fn setup() -> (
    ContractAddress,
    IERC721RedeemablesMixinDispatcher,
    IERC721RedeemablesMixinSafeDispatcher,
    ContractAddress,
    IERC721RedeemablesMixinDispatcher,
    IERC721RedeemablesMixinSafeDispatcher,
    ContractAddress,
    IERC721RedemptionMintableMixinDispatcher,
    IERC721RedemptionMintableMixinSafeDispatcher
) {
    let redeem_contract = declare("ERC721Redeemables");
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    let redeem_contract_address = redeem_contract.deploy(@calldata).unwrap();
    let redeem_token = IERC721RedeemablesMixinDispatcher {
        contract_address: redeem_contract_address
    };
    let redeem_token_safe = IERC721RedeemablesMixinSafeDispatcher {
        contract_address: redeem_contract_address
    };

    let second_redeem_contract_address = redeem_contract.deploy(@calldata).unwrap();
    let second_redeem_token = IERC721RedeemablesMixinDispatcher {
        contract_address: second_redeem_contract_address
    };
    let second_redeem_token_safe = IERC721RedeemablesMixinSafeDispatcher {
        contract_address: second_redeem_contract_address
    };

    let receive_contract = declare("ERC721RedemptionMintable");
    calldata.append_serde(test_address());
    let receive_contract_address = receive_contract.deploy(@calldata).unwrap();
    let receive_token = IERC721RedemptionMintableMixinDispatcher {
        contract_address: receive_contract_address
    };
    let receive_token_safe = IERC721RedemptionMintableMixinSafeDispatcher {
        contract_address: receive_contract_address
    };

    (
        redeem_contract_address,
        redeem_token,
        redeem_token_safe,
        second_redeem_contract_address,
        second_redeem_token,
        second_redeem_token_safe,
        receive_contract_address,
        receive_token,
        receive_token_safe
    )
}

fn offer_and_consideration(
    receive_contract_address: ContractAddress, redeem_contract_address: ContractAddress
) -> (OfferItem, Array<ConsiderationItem>) {
    let offer = OfferItem {
        item_type: ItemType::ERC721_WITH_CRITERIA,
        token: receive_contract_address,
        identifier_or_criteria: 0,
        start_amount: 1,
        end_amount: 1
    };

    let consideration = array![
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        }
    ];

    (offer, consideration)
}

#[test]
fn supports_interface() {
    let (
        _redeem_contract_address,
        redeem_token,
        _,
        _,
        _,
        _,
        _receive_contract_address,
        _receive_token,
        _
    ) =
        setup();
    assert!(redeem_token.supports_interface(IERC7498_ID));
}

#[test]
fn test_mint_token_success() {
    let (redeem_contract_address, redeem_token, _, _, _, _, _, _, _) = setup();

    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(OWNER(), TOKEN_ID);
}

#[test]
#[should_panic()]
fn test_mint_token_fails_not_owner() {
    let (redeem_contract_address, redeem_token, _, _, _, _, _, _receive_token, _) = setup();

    start_prank(CheatTarget::One(redeem_contract_address), ACCOUNT1());

    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(OWNER(), TOKEN_ID);
}

#[test]
#[should_panic()]
fn test_mint_token_fails_invalid_receiver() {
    let (redeem_contract_address, redeem_token, _, _, _, _, _, _receive_token, _) = setup();

    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(ZERO(), TOKEN_ID);
}

#[test]
fn test_burn_token_success() {
    let (_, redeem_token, _, _, _, _, _, _receive_token, _) = setup();

    redeem_token.mint(test_address(), TOKEN_ID);
    redeem_token.burn(TOKEN_ID);
}

#[test]
#[should_panic()]
fn test_burn_token_invalid_reciever() {
    let (_, redeem_token, _, _, _, _, _, _receive_token, _) = setup();

    redeem_token.mint(OWNER(), TOKEN_ID);
    redeem_token.burn(TOKEN_ID);
}

#[test]
fn test_create_campaign_success() {
    let (redeem_contract_address, redeem_token, _, _, _, _, receive_contract_address, _, _) =
        setup();

    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];
    offer_array.append(offer);

    let requirements = array![CampaignRequirements { offer: offer_array, consideration }];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();

    let params = CampaignParams {
        requirements,
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params, CAMPAIGN_URI());
}

#[test]
fn test_mint_redemption_success() {
    let (
        redeem_contract_address,
        redeem_token,
        _,
        _,
        _,
        _,
        receive_contract_address,
        receive_token,
        _
    ) =
        setup();

    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    receive_token.mint_redemption(CAMPAIGN_ID, test_address(), offer, consideration.span());
}

#[test]
#[should_panic()]
fn test_mint_redemption_fails_caller_not_owner() {
    let (
        redeem_contract_address,
        redeem_token,
        _,
        _,
        _,
        _,
        receive_contract_address,
        receive_token,
        _
    ) =
        setup();
    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    start_prank(CheatTarget::One(receive_contract_address), ACCOUNT1());

    receive_token.mint_redemption(CAMPAIGN_ID, OWNER(), offer, consideration.span());
}

#[test]
fn test_get_campaign() {
    let (redeem_contract_address, redeem_token, _, _, _, _, receive_contract_address, _, _) =
        setup();
    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];

    offer_array.append(offer);

    let requirements = array![CampaignRequirements { offer: offer_array, consideration }];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements,
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params.clone(), CAMPAIGN_URI());

    // get_campaign
    let (campaign_params, campaign_uri, total_redemptions) = redeem_token.get_campaign(CAMPAIGN_ID);

    let cparam_requirements = campaign_params.requirements;
    let cparam_signer = campaign_params.signer;
    let cparam_start_time = campaign_params.start_time;
    let cparam_end_time = campaign_params.end_time;
    let cparam_max_campaign_redemptions = campaign_params.max_campaign_redemptions;
    let cparam_manager = campaign_params.manager;

    assert!(campaign_uri == CAMPAIGN_URI(), "Campaign Base URI ERROR");
    assert!(total_redemptions == 0, "Total Redemption ERROR");
    assert!(cparam_signer == params.signer, "Signer ERROR");
    assert!(cparam_start_time == params.start_time, "Start Time ERROR");
    assert!(cparam_end_time == params.end_time, "End Time ERROR");
    assert!(
        cparam_max_campaign_redemptions == params.max_campaign_redemptions,
        "Max Campaign Redemptions ERROR"
    );
    assert!(cparam_manager == params.manager, "Manager ERROR");
    assert!(cparam_requirements.len() == params.requirements.len(), "Requirements ERROR");
}

#[test]
fn test_update_campaign() {
    let (redeem_contract_address, redeem_token, _, _, _, _, receive_contract_address, _, _) =
        setup();
    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];
    offer_array.append(offer);

    let requirements = array![CampaignRequirements { offer: offer_array, consideration }];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements,
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params.clone(), CAMPAIGN_URI());

    // update data
    let update_offer = array![
        OfferItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: receive_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1
        }
    ];

    let update_consideration = array![
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        }
    ];

    let update_requirements = array![
        CampaignRequirements { offer: update_offer, consideration: update_consideration }
    ];

    let update_params = CampaignParams {
        requirements: update_requirements,
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 10000,
        max_campaign_redemptions: 10,
        manager: test_address()
    };

    // update_campaign
    redeem_token.update_campaign(1, update_params.clone(), CAMPAIGN_URI_NEW());

    // get_campaign
    let (campaign_params, campaign_uri, total_redemptions) = redeem_token.get_campaign(CAMPAIGN_ID);

    let cparam_requirements = campaign_params.requirements;
    let cparam_signer = campaign_params.signer;
    let cparam_start_time = campaign_params.start_time;
    let cparam_end_time = campaign_params.end_time;
    let cparam_max_campaign_redemptions = campaign_params.max_campaign_redemptions;
    let cparam_manager = campaign_params.manager;

    assert!(campaign_uri == CAMPAIGN_URI_NEW(), "Campaign Base URI ERROR");
    assert!(total_redemptions == 0, "Total Redemption ERROR");
    assert!(cparam_signer == update_params.signer, "Signer ERROR");
    assert!(cparam_start_time == update_params.start_time, "Start Time ERROR");
    assert!(cparam_end_time == update_params.end_time, "End Time ERROR");
    assert!(
        cparam_max_campaign_redemptions == update_params.max_campaign_redemptions,
        "Max Campaign Redemptions ERROR"
    );
    assert!(cparam_manager == update_params.manager, "Manager ERROR");
    assert!(cparam_requirements.len() == update_params.requirements.len(), "Requirements ERROR");
}

#[test]
fn test_redeem_campaign() {
    let (redeem_contract_address, redeem_token, _, _, _, _, receive_contract_address, _, _) =
        setup();
    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];
    offer_array.append(offer);

    let requirements = array![CampaignRequirements { offer: offer_array, consideration }];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements,
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params.clone(), CAMPAIGN_URI());

    let extra_data = array![1, 0, 0];
    let consideration_token_ids = array![TOKEN_ID];

    start_prank(CheatTarget::One(receive_contract_address), test_address());

    redeem_token.redeem(consideration_token_ids.span(), test_address(), extra_data.span());

    // get_campaign
    let (_, _, total_redemptions) = redeem_token.get_campaign(CAMPAIGN_ID);
    assert!(total_redemptions == 1, "Total Redemption ERROR");
}
