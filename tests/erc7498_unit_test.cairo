use starknet::{ContractAddress, get_block_timestamp};
use snforge_std::{test_address};
use cairo_erc_7498::erc7498::interface::{
    BURN_ADDRESS, ItemType, OfferItem, ConsiderationItem, CampaignRequirements, CampaignParams,
};
use cairo_erc_7498::presets::erc721_redeemables::{IERC721RedeemablesMixinDispatcherTrait};
use cairo_erc_7498::presets::erc721_redemption::{IERC721RedemptionMintableMixinDispatcherTrait};
use snforge_std::{start_prank, CheatTarget};

use super::test_erc7498::{setup, NAME, SYMBOL, RECIPIENT, ZERO, CAMPAIGN_URI, TOKEN_ID};

const CAMPAIGN_ID: u256 = 1;

fn CAMPAIGN_URI_NEW() -> ByteArray {
    "https://example.com/new/campaign"
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
fn test_create_campaign_success() {
    let (redeem_contract_address, redeem_token, _, _, _, _, receive_contract_address, _, _) =
        setup();

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];
    offer_array.append(offer);

    let requirements = array![
        CampaignRequirements { offer: offer_array.span(), consideration: consideration.span() }
    ];

    let timestamp: u64 = get_block_timestamp().try_into().unwrap();

    let params = CampaignParams {
        requirements: requirements.span(),
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
    let (redeem_contract_address, _, _, _, _, _, receive_contract_address, receive_token, _) =
        setup();

    start_prank(CheatTarget::All(()), redeem_contract_address);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    receive_token.mint_redemption(CAMPAIGN_ID, test_address(), offer, consideration.span());
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_redemption_fails_caller_not_owner() {
    let (redeem_contract_address, _, _, _, _, _, receive_contract_address, receive_token, _) =
        setup();

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    receive_token.mint_redemption(CAMPAIGN_ID, RECIPIENT(), offer, consideration.span());
}

#[test]
fn test_get_campaign() {
    let (redeem_contract_address, redeem_token, _, _, _, _, receive_contract_address, _, _) =
        setup();

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];

    offer_array.append(offer);

    let requirements = array![
        CampaignRequirements { offer: offer_array.span(), consideration: consideration.span() }
    ];

    let timestamp: u64 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
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

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];
    offer_array.append(offer);

    let requirements = array![
        CampaignRequirements { offer: offer_array.span(), consideration: consideration.span() }
    ];

    let timestamp: u64 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
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
        CampaignRequirements {
            offer: update_offer.span(), consideration: update_consideration.span()
        }
    ];

    let update_params = CampaignParams {
        requirements: update_requirements.span(),
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 10000,
        max_campaign_redemptions: 10,
        manager: test_address()
    };

    // update_campaign
    redeem_token.update_campaign(CAMPAIGN_ID, update_params.clone(), CAMPAIGN_URI_NEW());

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

    redeem_token.mint(test_address(), TOKEN_ID);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];
    offer_array.append(offer);

    let requirements = array![
        CampaignRequirements { offer: offer_array.span(), consideration: consideration.span() }
    ];

    let timestamp: u64 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params.clone(), CAMPAIGN_URI());

    let extra_data = array![1, 0, 0];
    let consideration_token_ids = array![TOKEN_ID];

    start_prank(CheatTarget::One(redeem_contract_address), test_address());

    redeem_token.redeem(consideration_token_ids.span(), test_address(), extra_data.span());

    let (_, _, total_redemptions) = redeem_token.get_campaign(CAMPAIGN_ID);
    assert!(total_redemptions == 1, "Total Redemption ERROR");
}

// boundary check
#[test]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_redeem_campaign_boundary_check() {
    let (redeem_contract_address, redeem_token, _, _, _, _, receive_contract_address, _, _) =
        setup();

    redeem_token.mint(test_address(), TOKEN_ID);

    let (offer, consideration) = offer_and_consideration(
        receive_contract_address, redeem_contract_address
    );

    let mut offer_array = array![];
    offer_array.append(offer);

    let requirements = array![
        CampaignRequirements { offer: offer_array.span(), consideration: consideration.span() }
    ];

    let timestamp: u64 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params.clone(), CAMPAIGN_URI());

    let extra_data = array![1, 0, 0];
    let consideration_token_ids = array![TOKEN_ID];

    start_prank(CheatTarget::One(redeem_contract_address), test_address());

    redeem_token.redeem(consideration_token_ids.span(), test_address(), extra_data.span());

    let (_, _, total_redemptions) = redeem_token.get_campaign(CAMPAIGN_ID);
    assert!(total_redemptions == 1, "Total Redemption ERROR");

    // Call the function or code that you expect to fail with the specific error message
    redeem_token.redeem(consideration_token_ids.span(), test_address(), extra_data.span());
}
