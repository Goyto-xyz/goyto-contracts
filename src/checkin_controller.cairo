#[derive(Drop, Serde, starknet::Store)]
pub struct CheckInData {
  spot_id: u256,
  streak_count: u256,
  timestamp: u64,
  ipfs_hash: ByteArray
}

#[derive(Drop, Serde, starknet::Store)]
pub struct BonusPoints {
  streak_bonus: u256,
  photo_bonus: u256,
  friends_bonus: u256,
  new_spot_bonus: u256
}

#[starknet::contract]
pub mod CheckinController {
  use starknet::storage::{
    Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,
    Vec, VecTrait, MutableVecTrait,
  };
  use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
  use travio::interfaces::spot_manager::{ISpotManagerDispatcher, ISpotManagerDispatcherTrait};
  use travio::interfaces::user_manager::{IUserManagerDispatcher, IUserManagerDispatcherTrait};
  use travio::interfaces::checkin_controller::ICheckinController;
  use super::CheckInData;
  use super::BonusPoints;

  const ADD_SPOT_POINTS: u256 = 20;
  const CHECK_IN_POINTS: u256 = 10;
  const STREAK_BONUS_MULTIPLIER: u256 = 2;
  const FRIEND_BONUS_MULTIPLIER: u256 = 2;
  const PHOTO_BONUS_POINTS: u256 = 5;
  const NEW_SPOT_BONUS_POINTS: u256 = 3;

  #[storage]
  struct Storage {
    user_manager: ContractAddress,
    spot_manager: ContractAddress,
    user_checkin_data: Map<ContractAddress, Vec<CheckInData>> // User => CheckInData[]
  }

  #[event]
  #[derive(starknet::Event, Drop)]
  pub enum Event {
    SpotAdded: SpotAdded,
    CheckIn: CheckIn
  }

  #[derive(starknet::Event, Drop)]
  pub struct SpotAdded {
    pub user: ContractAddress,
    pub spot_id: u256,
    pub ipfs_hash: ByteArray,
    pub points_earned: u256,
  }

  #[derive(starknet::Event, Drop)]
  pub struct CheckIn {
    pub user: ContractAddress,
    pub spot_id: u256,
    pub points_earned: u256,
    pub streak_bonus: u256,
    pub photo_bonus: u256,
    pub friends_bonus: u256,
    pub new_spot_bonus: u256,
    pub ipfs_hash: ByteArray
  }

  #[constructor]
  fn constructor(ref self: ContractState, spot_manager: ContractAddress, user_manager: ContractAddress) {
    self.spot_manager.write(spot_manager);
    self.user_manager.write(user_manager);
  }

  #[abi(embed_v0)]
  impl CheckinControllerImpl of ICheckinController<ContractState> {
    fn add_spot(ref self: ContractState, ipfs_hash: ByteArray) {
      let spot_manager_contract: ISpotManagerDispatcher = ISpotManagerDispatcher { contract_address: self.spot_manager.read() };
      let user_manager_contract: IUserManagerDispatcher = IUserManagerDispatcher { contract_address: self.user_manager.read() };

      let spot_id = spot_manager_contract.add_spot(ipfs_hash.clone());

      let user = get_caller_address();
      user_manager_contract.update_user_points(user, ADD_SPOT_POINTS, 0);
      user_manager_contract.update_user_spot_added(user, spot_id);

      self.emit(SpotAdded {
        user,
        spot_id,
        ipfs_hash,
        points_earned: ADD_SPOT_POINTS
      });
    }

    fn checkin(ref self: ContractState, spot_id: u256, with_media: bool, friend_count: u256, ipfs_hash: ByteArray) {
      let user = get_caller_address();
      let spot_manager_contract: ISpotManagerDispatcher = ISpotManagerDispatcher { contract_address: self.spot_manager.read() };
      let user_manager_contract: IUserManagerDispatcher = IUserManagerDispatcher { contract_address: self.user_manager.read() };

      spot_manager_contract.checkin_spot(spot_id);
      let (streak_count, is_new_spot) = self.get_checkin_status(user, spot_id);

      let bonus_points = self.caculate_bonus_points(user, spot_id, with_media, friend_count, streak_count - 1, is_new_spot);
      let points_earned = CHECK_IN_POINTS + bonus_points.streak_bonus + bonus_points.photo_bonus + bonus_points.friends_bonus + bonus_points.new_spot_bonus;

      user_manager_contract.update_user_points(user, points_earned, 0);
      user_manager_contract.update_user_checkin(user, spot_id);

      // Update check-in data
      let new_checkin = CheckInData {
        spot_id,
        streak_count,
        timestamp: get_block_timestamp(),
        ipfs_hash: ipfs_hash.clone()
      };

      self.user_checkin_data.entry(user).append().write(new_checkin);

      self.emit(CheckIn {
        user,
        spot_id,
        points_earned,
        streak_bonus: bonus_points.streak_bonus,
        photo_bonus: bonus_points.photo_bonus,
        friends_bonus: bonus_points.friends_bonus,
        new_spot_bonus: bonus_points.new_spot_bonus,
        ipfs_hash
      });
    }

    fn get_spot_manager(self: @ContractState) -> ContractAddress {
      self.spot_manager.read()
    }

    fn get_user_manager(self: @ContractState) -> ContractAddress {
      self.user_manager.read()
    }

    fn get_checkin_history(self: @ContractState, user: ContractAddress) -> Array<(u256, u256, u64, ByteArray)> {
      let length = self.user_checkin_data.entry(user).len();
      let mut i: u64 = 0;
      let mut history: Array<(u256, u256, u64, ByteArray)> = array![];

      while (i < length) {
        let data = self.user_checkin_data.entry(user).at(i).read();
        history.append((
          data.spot_id,
          data.streak_count,
          data.timestamp,
          data.ipfs_hash
        ));

        i = i + 1;
      };

      history
    }
  }

  #[generate_trait]
  impl InternalFunctions of InternalFunctionsTrait {
    ///
    ///  Calculate the points earned for a check-in
    ///
    fn caculate_bonus_points(self: @ContractState, user: ContractAddress, spot_id: u256, with_media: bool, friend_count: u256, streak_count: u256, is_new_spot: bool) -> BonusPoints {
      let streak_bonus: u256 = streak_count * STREAK_BONUS_MULTIPLIER;
      let photo_bonus: u256 = if with_media { PHOTO_BONUS_POINTS } else { 0 };
      let friends_bonus: u256 = if friend_count > 0 { friend_count * FRIEND_BONUS_MULTIPLIER } else { 0 };
      let new_spot_bonus: u256 = if is_new_spot { NEW_SPOT_BONUS_POINTS } else { 0 };

      return BonusPoints {
        streak_bonus,
        photo_bonus,
        friends_bonus,
        new_spot_bonus
      };
    }

    fn get_checkin_status(self: @ContractState, user: ContractAddress, spot_id: u256) -> (u256, bool) {
      let mut streak_count = 1;
      let mut is_new_spot = true;

      let checkin_data_len = self.user_checkin_data.entry(user).len();
      let mut i: u64 = checkin_data_len;

      while (i > 0) {
        let last_checkin = self.user_checkin_data.entry(user).at(i - 1).read();
        i = i - 1;

        if (last_checkin.spot_id == spot_id) {
          is_new_spot = false;

          let current_day = get_block_timestamp() / (24 * 60 * 60);
          let last_checkin_day = last_checkin.timestamp / (24 * 60 * 60);

          if (current_day == last_checkin_day) {
            break;
          } else if (current_day == last_checkin_day + 1) {
              streak_count = last_checkin.streak_count + 1;
          } else {
              streak_count = 1;
          }

          break;
        }
      };

      (streak_count, is_new_spot)
    }
  }
}
