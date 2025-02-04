#[cfg(test)]
mod CheckinControllerTest {
  use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_timestamp, stop_cheat_block_timestamp,
    spy_events, EventSpyAssertionsTrait
  };
  use starknet::contract_address_const;
  use travio::interfaces::spot_manager::{ISpotManagerDispatcher, ISpotManagerDispatcherTrait};
  use travio::interfaces::user_manager::{IUserManagerDispatcher, IUserManagerDispatcherTrait};
  use travio::interfaces::checkin_controller::{ICheckinControllerDispatcher, ICheckinControllerDispatcherTrait};
  use travio::spot_manager::SpotManager;
  use travio::user_manager::UserManager;
  use travio::checkin_controller::CheckinController;

  fn deploy() -> (ISpotManagerDispatcher, IUserManagerDispatcher, ICheckinControllerDispatcher) {
    let owner = contract_address_const::<0x111111>();

    let (contract_address, _) = declare("SpotManager").unwrap().contract_class().deploy(@array![owner.into()]).unwrap();
    let spot_manager = ISpotManagerDispatcher { contract_address };

    let (contract_address, _) = declare("UserManager").unwrap().contract_class().deploy(@array![owner.into()]).unwrap();
    let user_manager = IUserManagerDispatcher { contract_address };

    let spot_manager_address = spot_manager.contract_address.into();
    let user_manager_address = user_manager.contract_address.into();

    let (contract_address, _) = declare("CheckinController").unwrap().contract_class()
      .deploy(@array![spot_manager_address, user_manager_address]).unwrap();
    let checkin_controller = ICheckinControllerDispatcher { contract_address };

    start_cheat_caller_address(spot_manager.contract_address, 0x111111.try_into().unwrap());
    start_cheat_caller_address(user_manager.contract_address, 0x111111.try_into().unwrap());

    spot_manager.set_checkin_controller(checkin_controller.contract_address);
    user_manager.set_checkin_controller(checkin_controller.contract_address);

    stop_cheat_caller_address(spot_manager.contract_address);
    stop_cheat_caller_address(user_manager.contract_address);

    (spot_manager, user_manager, checkin_controller)
  }

  #[test]
  fn test_add_spot() {
    let (spot_manager, user_manager, checkin_controller) = deploy();
    let mut spy = spy_events();
    let user = contract_address_const::<0x222222>();

    start_cheat_caller_address(checkin_controller.contract_address, user);
    checkin_controller.add_spot("QmHash");

    let (_, _, ipfs_hash) = spot_manager.get_spot_info(0);

    assert(ipfs_hash == "QmHash", 'ipfsh hash = QmHash');
    assert(spot_manager.get_total_spots() == 1, 'total_spots = 1');

    let (total_points, _, spot_added) = user_manager.get_user_info(user);
    assert(total_points == 20, 'user points = 20');
    assert(spot_added == 1, 'spot added count = 1');

    spy.assert_emitted(@array![(
      spot_manager.contract_address,
      SpotManager::Event::SpotAdded (
        SpotManager::SpotAdded { spot_id: 0, ipfs_hash: "QmHash" }
      )
    )]);

    spy.assert_emitted(@array![(
      user_manager.contract_address,
      UserManager::Event::UserPointsUpdated(
        UserManager::UserPointsUpdated { user, points: 20, sub_points: 0, total_points: 20 }
      )
    )]);

    spy.assert_emitted(@array![(
      checkin_controller.contract_address,
      CheckinController::Event::SpotAdded(
        CheckinController::SpotAdded {
          user,
          spot_id: 0,
          ipfs_hash,
          points_earned: 20
        }
      )
    )]);

    stop_cheat_caller_address(checkin_controller.contract_address);
  }

  #[test]
  fn test_checkin() {
    let (spot_manager, user_manager, checkin_controller) = deploy();
    let mut spy = spy_events();
    let user = contract_address_const::<0x222222>();

    start_cheat_caller_address(checkin_controller.contract_address, user);
    checkin_controller.add_spot("QmHash");

    let history = checkin_controller.get_checkin_history(user);
    assert(history.len() == 0, 'history length = 0');

    let checkin_ipfs = "checkin_ipfs_hash";
    let t = 1736942000;

    start_cheat_block_timestamp(checkin_controller.contract_address, t);
    checkin_controller.checkin(0, true, 1, checkin_ipfs.clone());
    stop_cheat_block_timestamp(checkin_controller.contract_address);

    let new_history = checkin_controller.get_checkin_history(user);
    assert(new_history.len() == 1, 'history length = 1');

    let (spot_id, streak_count, _, ipfs_hash) = new_history[0];
    assert(*spot_id == 0, 'spot_id = 0');
    assert(*streak_count == 1, 'streak_count = 1');
    assert((ipfs_hash == @checkin_ipfs), 'ipfs_hash correct');

    let (total_points, total_checkins, _) = user_manager.get_user_info(user);
    assert(total_points == 40, 'user points = 40');
    assert(total_checkins == 1, 'total_checkins = 1');

    spy.assert_emitted(@array![(
      spot_manager.contract_address,
      SpotManager::Event::SpotCheckedIn(
        SpotManager::SpotCheckedIn { spot_id: 0, checkin_count: 1 }
      )
    )]);

    spy.assert_emitted(@array![(
      user_manager.contract_address,
      UserManager::Event::UserPointsUpdated(
        UserManager::UserPointsUpdated { user, points: 20, sub_points: 0, total_points: 40 }
      )
    )]);

    spy.assert_emitted(@array![(
      checkin_controller.contract_address,
      CheckinController::Event::CheckIn(
        CheckinController::CheckIn {
          user,
          spot_id: 0,
          points_earned: 20,
          streak_bonus: 0,
          photo_bonus: 5,
          friends_bonus: 2,
          new_spot_bonus: 3,
          ipfs_hash: checkin_ipfs
        }
      )
    )]);

    stop_cheat_caller_address(checkin_controller.contract_address);
  }

  #[test]
  fn test_streak_bonus_in_same_day() {
    let (_, user_manager, checkin_controller) = deploy();
    let mut spy = spy_events();
    let user = contract_address_const::<0x333333>();

    start_cheat_caller_address(checkin_controller.contract_address, user);
    checkin_controller.add_spot("QmHash");

    let checkin_ipfs = "checkin_ipfs_hash";
    let t = 1736942000;

    start_cheat_block_timestamp(checkin_controller.contract_address, t);
    checkin_controller.checkin(0, true, 1, checkin_ipfs.clone());

    // Second check-in in next 1 hour
    start_cheat_block_timestamp(checkin_controller.contract_address, t + 1 * 60 * 60);

    let checkin_ipfs_2 = "checkin_ipfs_hash_2";
    checkin_controller.checkin(0, false, 0, checkin_ipfs_2.clone());
    stop_cheat_block_timestamp(checkin_controller.contract_address);

    let (total_points, total_checkins, _) = user_manager.get_user_info(user);

    let history = checkin_controller.get_checkin_history(user);
    assert(history.len() == 2, 'history length = 2');

    let (_, streak_count, _, ipfs_hash) = history[0];
    assert(*streak_count == 1, 'streak_count = 1');
    assert((ipfs_hash == @checkin_ipfs), 'ipfs_hash correct');

    let (_, streak_count_2, _, ipfs_hash_2) = history[1];
    assert(*streak_count_2 == 1, 'streak_count_2 = 1');
    assert((ipfs_hash_2 == @checkin_ipfs_2), 'ipfs_hash_2 correct');

    assert(total_points == 50, 'user points = 50');
    assert(total_checkins == 2, 'total_checkins = 2');

    spy.assert_emitted(@array![(
      user_manager.contract_address,
      UserManager::Event::UserPointsUpdated(
        UserManager::UserPointsUpdated { user, points: 10, sub_points: 0, total_points: 50 }
      )
    )]);

    spy.assert_emitted(@array![(
      checkin_controller.contract_address,
      CheckinController::Event::CheckIn(
        CheckinController::CheckIn {
          user,
          spot_id: 0,
          points_earned: 10,
          streak_bonus: 0,
          photo_bonus: 0,
          friends_bonus: 0,
          new_spot_bonus: 0,
          ipfs_hash: checkin_ipfs_2
        }
      )
    )]);
  }

  #[test]
  fn test_streak_bonus_in_diff_day() {
    let (_, user_manager, checkin_controller) = deploy();
    let mut spy = spy_events();
    let user = contract_address_const::<0x222222>();

    start_cheat_caller_address(checkin_controller.contract_address, user);
    checkin_controller.add_spot("QmHash");

    let checkin_ipfs = "checkin_ipfs_hash";
    let timestamp = 1736942000;

    start_cheat_block_timestamp(checkin_controller.contract_address, timestamp);
    checkin_controller.checkin(0, true, 1, checkin_ipfs.clone());

    // Second check-in
    start_cheat_block_timestamp(checkin_controller.contract_address, timestamp + 24 * 60 * 60);
    let checkin_ipfs_2 = "checkin_ipfs_hash_2";
    checkin_controller.checkin(0, false, 0, checkin_ipfs_2.clone());

    let (total_points, total_checkins, _) = user_manager.get_user_info(user);

    let history = checkin_controller.get_checkin_history(user);
    assert(history.len() == 2, 'history length = 2');

    let (_, streak_count, _, ipfs_hash) = history[0];
    assert(*streak_count == 1, 'streak_count = 1');
    assert((ipfs_hash == @checkin_ipfs), 'ipfs_hash correct');

    let (_, streak_count_2, _, ipfs_hash_2) = history[1];
    assert(*streak_count_2 == 2, 'streak_count_2 = 2');
    assert((ipfs_hash_2 == @checkin_ipfs_2), 'ipfs_hash_2 correct');

    assert(total_points == 52, 'user points = 52');
    assert(total_checkins == 2, 'total_checkins = 2');

    spy.assert_emitted(@array![(
      user_manager.contract_address,
      UserManager::Event::UserPointsUpdated(
        UserManager::UserPointsUpdated { user, points: 12, sub_points: 0, total_points: 52 }
      )
    )]);

    spy.assert_emitted(@array![(
      checkin_controller.contract_address,
      CheckinController::Event::CheckIn(
        CheckinController::CheckIn {
          user,
          spot_id: 0,
          points_earned: 12,
          streak_bonus: 2,
          photo_bonus: 0,
          friends_bonus: 0,
          new_spot_bonus: 0,
          ipfs_hash: checkin_ipfs_2
        }
      )
    )]);

    // Third check-in in 2 days later, streak_count should be 3
    start_cheat_block_timestamp(checkin_controller.contract_address, timestamp + 2 * 24 * 60 * 60);
    let checkin_ipfs_3 = "checkin_ipfs_hash_3";
    checkin_controller.checkin(0, false, 0, checkin_ipfs_3.clone());
    stop_cheat_block_timestamp(checkin_controller.contract_address);

    let new_history = checkin_controller.get_checkin_history(user);

    let (_, streak_count_3, _, _) = new_history[2];
    assert(*streak_count_3 == 3, 'streak_count_3 = 3');
    let (new_total_points, _, _) = user_manager.get_user_info(user);
    assert(new_total_points == 66, 'user points = 66');

    // Fourth check-in in 1 weeks later, streak_count should be reset to 1
    start_cheat_block_timestamp(checkin_controller.contract_address, timestamp + 7 * 24 * 60 * 60);
    let checkin_ipfs_3 = "checkin_ipfs_hash_4";
    checkin_controller.checkin(0, false, 0, checkin_ipfs_3.clone());
    stop_cheat_block_timestamp(checkin_controller.contract_address);

    let new_history = checkin_controller.get_checkin_history(user);
    let (_, streak_count_4, _, _) = new_history[3];

    assert(*streak_count_4 == 1, 'streak_count_4 = 1');
    let (new_total_points, _, _) = user_manager.get_user_info(user);
    assert(new_total_points == 76, 'user points = 76');

    stop_cheat_caller_address(checkin_controller.contract_address);
  }
}
