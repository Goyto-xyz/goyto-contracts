#[cfg(test)]
mod SpotManagerTest {
  use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    start_cheat_caller_address, stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait
  };
  use starknet::{contract_address_const};
  use travio::interfaces::spot_manager::{ISpotManagerDispatcher, ISpotManagerDispatcherTrait};
  use travio::spot_manager::SpotManager;

  fn deploy() -> ISpotManagerDispatcher {
    let owner = contract_address_const::<0x111111>();
    let (contract_address, _) = declare("SpotManager").unwrap().contract_class().deploy(@array![owner.into()]).unwrap();
    let spot_manager = ISpotManagerDispatcher { contract_address };
    spot_manager
  }

  #[test]
  fn test_constructor() {
    let spot_manager = deploy();
    let total_spots = spot_manager.get_total_spots();
    assert(total_spots == 0, 'total_spots == 0');
  }

  #[test]
  fn test_set_checkin_controller() {
    let spot_manager = deploy();
    let checkin_controller_address = contract_address_const::<0x1234567890>();
    start_cheat_caller_address(spot_manager.contract_address, 0x111111.try_into().unwrap());
    spot_manager.set_checkin_controller(checkin_controller_address);
    assert(spot_manager.get_checkin_controller() == checkin_controller_address, 'checkin_controller');
    stop_cheat_caller_address(spot_manager.contract_address);
  }

  #[test]
  #[should_panic]
  fn test_set_checkin_controller_panic() {
    let spot_manager = deploy();
    let checkin_controller_address = contract_address_const::<0x1234567890>();
    start_cheat_caller_address(spot_manager.contract_address, 123.try_into().unwrap());

    spot_manager.set_checkin_controller(checkin_controller_address);

    stop_cheat_caller_address(spot_manager.contract_address);
  }

  #[test]
  #[should_panic(expected: 'NOT_CHECKIN_CONTROLLER')]
  fn test_add_spot_panic () {
    let spot_manager = deploy();
    spot_manager.add_spot("0x123456789");
  }

  #[test]
  fn test_add_spot() {
    let spot_manager = deploy();
    let checkin_controller_address = contract_address_const::<0x1234567890>();

    start_cheat_caller_address(spot_manager.contract_address, 0x111111.try_into().unwrap());
    spot_manager.set_checkin_controller(checkin_controller_address);

    let mut spy = spy_events();

    start_cheat_caller_address(spot_manager.contract_address, checkin_controller_address);
    spot_manager.add_spot("0x123456789");
    stop_cheat_caller_address(spot_manager.contract_address);

    let (_, _, ipfs_hash) = spot_manager.get_spot_info(0);
    assert(ipfs_hash == "0x123456789", 'ipfs_hash == 0x123456789');
    assert(spot_manager.get_total_spots() == 1, 'total_spots == 1');

    spy.assert_emitted(@array![(
      spot_manager.contract_address,
      SpotManager::Event::SpotAdded(
        SpotManager::SpotAdded { spot_id: 0, ipfs_hash: "0x123456789" }
      )
    )]);
  }

  #[test]
  #[should_panic(expected: 'NOT_CHECKIN_CONTROLLER')]
  fn test_checkin_spot_panic_not_checkin_controller() {
    let spot_manager = deploy();
    spot_manager.checkin_spot(0);
  }

  #[test]
  #[should_panic(expected: 'SPOT_DOES_NOT_EXIST')]
  fn test_checkin_spot_panic_spot_does_not_exist() {
    let spot_manager = deploy();
    let checkin_controller_address = contract_address_const::<0x1234567890>();

    start_cheat_caller_address(spot_manager.contract_address, 0x111111.try_into().unwrap());
    spot_manager.set_checkin_controller(checkin_controller_address);

    start_cheat_caller_address(spot_manager.contract_address, checkin_controller_address);
    spot_manager.checkin_spot(0);
    stop_cheat_caller_address(spot_manager.contract_address);
  }

  #[test]
  fn test_checkin_spot() {
    let spot_manager = deploy();
    let checkin_controller_address = contract_address_const::<0x1234567890>();

    start_cheat_caller_address(spot_manager.contract_address, 0x111111.try_into().unwrap());
    spot_manager.set_checkin_controller(checkin_controller_address);

    let mut spy = spy_events();

    start_cheat_caller_address(spot_manager.contract_address, checkin_controller_address);
    spot_manager.add_spot("0x123456789");
    spot_manager.checkin_spot(0);
    stop_cheat_caller_address(spot_manager.contract_address);

    let (_, checkin_count, _) = spot_manager.get_spot_info(0);
    assert(checkin_count == 1, 'checkin_count == 1');

    spy.assert_emitted(@array![(
      spot_manager.contract_address,
      SpotManager::Event::SpotCheckedIn(
        SpotManager::SpotCheckedIn { spot_id: 0, checkin_count: 1 }
      )
    )]);
  }

  #[test]
  #[should_panic(expected: 'SPOT_DOES_NOT_EXIST')]
  fn test_get_spot_info_panic() {
    let spot_manager = deploy();
    spot_manager.get_spot_info(0);
  }
}
