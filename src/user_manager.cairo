#[derive(Drop, Serde, starknet::Store)]
pub struct User {
  total_points: u256,
  total_checkins: u256,
  spots_added: u256,
}

#[starknet::contract]
pub mod UserManager {
  use starknet::{ContractAddress, get_caller_address};
  use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
  use travio::interfaces::user_manager::IUserManager;
  use travio::ownable::{OwnableComponent, OwnableComponent::OwnableInternalTrait};
  use super::User;

  component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

  #[abi(embed_v0)]
  impl OwnableImpl = OwnableComponent::Ownable<ContractState>;

  #[storage]
  struct Storage {
    #[substorage(v0)]
    ownable: OwnableComponent::Storage,
    checkin_controller: ContractAddress,
    users: Map<ContractAddress, User>,
  }

  #[event]
  #[derive(starknet::Event, Drop)]
  pub enum Event {
    OwnableEvent: OwnableComponent::Event,
    UserPointsUpdated: UserPointsUpdated,
  }

  #[derive(starknet::Event, Drop)]
  pub struct UserPointsUpdated {
    pub user: ContractAddress,
    pub points: u256,
    pub sub_points: u256,
    pub total_points: u256,
  }

  #[constructor]
  fn constructor(ref self: ContractState, owner: ContractAddress) {
    self.ownable._init(owner);
  }

  #[abi(embed_v0)]
  impl UserManagerImpl of IUserManager<ContractState>{

    fn set_checkin_controller(ref self: ContractState, checkin_controller: ContractAddress) {
      self.ownable._assert_only_owner();
      self.checkin_controller.write(checkin_controller);
    }

    fn update_user_points(ref self: ContractState, user: ContractAddress, points: u256, sub_points: u256) {
      assert(self.is_checkin_controller(), 'NOT_CHECKIN_CONTROLLER');

      let mut user_info = self.users.read(user);
      let mut total_points = user_info.total_points;

      total_points += points;

      if (sub_points > 0) {
        total_points -= sub_points;
      }

      user_info.total_points = total_points;
      self.users.write(user, user_info);

      self.emit(UserPointsUpdated {
        user,
        points,
        sub_points,
        total_points
      });
    }

    fn update_user_checkin(ref self: ContractState, user: ContractAddress, spot_id: u256) {
      assert(self.is_checkin_controller(), 'NOT_CHECKIN_CONTROLLER');

      let mut user_info = self.users.read(user);
      let mut total_checkins = user_info.total_checkins;

      total_checkins += 1;

      user_info.total_checkins = total_checkins;
      self.users.write(user, user_info);
    }

    fn update_user_spot_added(ref self: ContractState, user: ContractAddress, spot_id: u256) {
      assert(self.is_checkin_controller(), 'NOT_CHECKIN_CONTROLLER');

      let mut user_info = self.users.read(user);
      let mut spots_added = user_info.spots_added;

      spots_added += 1;

      user_info.spots_added = spots_added;
      self.users.write(user, user_info);
    }

    fn get_user_info(self: @ContractState, user: ContractAddress) -> (u256, u256, u256) {
      let user_info = self.users.read(user);
      (user_info.total_points, user_info.total_checkins, user_info.spots_added)
    }

    fn get_checkin_controller(self: @ContractState) -> ContractAddress {
      self.checkin_controller.read()
    }
  }

  #[generate_trait]
  impl Private of PrivateTrait {
    fn is_checkin_controller(self: @ContractState) -> bool {
      self.checkin_controller.read() == get_caller_address()
    }
  }
}
