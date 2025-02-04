#[cfg(test)]
mod UserManagerTest {
  use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    start_cheat_caller_address, stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait
  };
  use starknet::{get_caller_address, contract_address_const};
  use travio::interfaces::user_manager::{IUserManagerDispatcher, IUserManagerDispatcherTrait};
  use travio::user_manager::UserManager;

  fn deploy() -> IUserManagerDispatcher {
    let owner = contract_address_const::<0x111111>();
    let (contract_address, _) = declare("UserManager").unwrap().contract_class().deploy(@array![owner.into()]).unwrap();
    let user_manager = IUserManagerDispatcher { contract_address };
    user_manager
  }

  #[test]
  fn test_constructor() {
    let user_manager = deploy();
    let (total_points, _, _) = user_manager.get_user_info(get_caller_address());
    assert(total_points == 0, 'user point = 0');
  }

  #[test]
  fn test_set_checkin_controller() {
    let user_manager = deploy();
    let checkin_controller_address = contract_address_const::<0x1234567890>();
    start_cheat_caller_address(user_manager.contract_address, 0x111111.try_into().unwrap());
    user_manager.set_checkin_controller(checkin_controller_address);
    assert(user_manager.get_checkin_controller() == checkin_controller_address, 'checkin_controller');
    stop_cheat_caller_address(user_manager.contract_address);
  }

  #[test]
  #[should_panic]
  fn test_set_checkin_controller_panic() {
    let user_manager = deploy();
    let checkin_controller_address = contract_address_const::<0x1234567890>();
    start_cheat_caller_address(user_manager.contract_address, 123.try_into().unwrap());

    user_manager.set_checkin_controller(checkin_controller_address);

    stop_cheat_caller_address(user_manager.contract_address);
  }

  #[test]
  #[should_panic(expected: 'NOT_CHECKIN_CONTROLLER')]
  fn test_update_user_points_panic() {
    let user_manager = deploy();
    let user = get_caller_address();
    user_manager.update_user_points(user, 10, 5);
  }

  #[test]
  fn test_update_user_points() {
    let user_manager = deploy();
    let user = get_caller_address();

    start_cheat_caller_address(user_manager.contract_address, 0x111111.try_into().unwrap());
    let checkin_controller_address = contract_address_const::<0x1234567890>();
    user_manager.set_checkin_controller(checkin_controller_address);

    let mut spy = spy_events();

    start_cheat_caller_address(user_manager.contract_address, checkin_controller_address);
    user_manager.update_user_points(user, 10, 5);
    stop_cheat_caller_address(user_manager.contract_address);

    let (total_points, _, _) = user_manager.get_user_info(user);
    assert(total_points == 5, 'user_points = 5');

    spy.assert_emitted(@array![(
      user_manager.contract_address,
      UserManager::Event::UserPointsUpdated(
        UserManager::UserPointsUpdated { user, points: 10, sub_points: 5, total_points: 5 }
      )
    )]);
  }

  #[test]
  #[should_panic(expected: 'NOT_CHECKIN_CONTROLLER')]
  fn test_update_user_checkin_panic() {
    let user_manager = deploy();
    let user = get_caller_address();
    user_manager.update_user_checkin(user, 0);
  }

  #[test]
  fn test_update_user_checkin() {
    let user_manager = deploy();
    let user = get_caller_address();
    let checkin_controller_address = contract_address_const::<0x1234567890>();

    start_cheat_caller_address(user_manager.contract_address, 0x111111.try_into().unwrap());
    user_manager.set_checkin_controller(checkin_controller_address);

    start_cheat_caller_address(user_manager.contract_address, checkin_controller_address);
    user_manager.update_user_checkin(user, 0);
    stop_cheat_caller_address(user_manager.contract_address);

    let (_, total_checkins, _) = user_manager.get_user_info(user);
    assert(total_checkins == 1, 'user_checkin_count = 1');
  }

  #[test]
  #[should_panic(expected: 'NOT_CHECKIN_CONTROLLER')]
  fn test_update_user_spot_added_panic() {
    let user_manager = deploy();
    let user = get_caller_address();
    user_manager.update_user_spot_added(user, 0);
  }

  #[test]
  fn test_update_user_spot_added() {
    let user_manager = deploy();
    let user = get_caller_address();
    let checkin_controller_address = contract_address_const::<0x1234567890>();

    start_cheat_caller_address(user_manager.contract_address, 0x111111.try_into().unwrap());
    user_manager.set_checkin_controller(checkin_controller_address);

    start_cheat_caller_address(user_manager.contract_address, checkin_controller_address);
    user_manager.update_user_spot_added(user, 1);
    stop_cheat_caller_address(user_manager.contract_address);

    let (_, _, spots_added) = user_manager.get_user_info(user);
    assert(spots_added == 1, 'user_checkin_count = 1');
  }
}
