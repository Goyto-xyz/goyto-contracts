#[derive(Drop, Serde, starknet::Store)]
pub struct Spot {
  spot_id: u256,
  checkin_count: u256,
  ipfs_hash: ByteArray,
}

#[starknet::contract]
pub mod SpotManager {
  use starknet::{ContractAddress, get_caller_address};
  use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
  use travio::interfaces::spot_manager::ISpotManager;
  use travio::ownable::{OwnableComponent, OwnableComponent::OwnableInternalTrait};
  use super::Spot;

  component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

  #[abi(embed_v0)]
  impl OwnableImpl = OwnableComponent::Ownable<ContractState>;

  #[storage]
  struct Storage {
    #[substorage(v0)]
    ownable: OwnableComponent::Storage,
    checkin_controller: ContractAddress,
    spots: Map<u256, Spot>,
    total_spots: u256
  }

  #[event]
  #[derive(starknet::Event, Drop)]
  pub enum Event {
    OwnableEvent: OwnableComponent::Event,
    SpotAdded: SpotAdded,
    SpotCheckedIn: SpotCheckedIn
  }

  #[derive(starknet::Event, Drop)]
  pub struct SpotAdded {
    pub spot_id: u256,
    pub ipfs_hash: ByteArray
  }

  #[derive(starknet::Event, Drop)]
  pub struct SpotCheckedIn {
    pub spot_id: u256,
    pub checkin_count: u256
  }

  #[constructor]
  fn constructor(ref self: ContractState, owner: ContractAddress) {
    self.total_spots.write(0);
    self.ownable._init(owner);
  }

  #[abi(embed_v0)]
  impl SpotManagerImpl of ISpotManager<ContractState> {

    fn set_checkin_controller(ref self: ContractState, checkin_controller: ContractAddress) {
      self.ownable._assert_only_owner();
      self.checkin_controller.write(checkin_controller);
    }

    fn add_spot(ref self: ContractState, ipfs_hash: ByteArray) -> u256 {
      assert(self.is_checkin_controller(), 'NOT_CHECKIN_CONTROLLER');

      let spot_id = self.total_spots.read();
      let spot = Spot {
        spot_id,
        checkin_count: 0,
        ipfs_hash: ipfs_hash.clone()
      };

      self.spots.write(spot_id, spot);
      self.total_spots.write(spot_id + 1);

      self.emit(SpotAdded {
        spot_id,
        ipfs_hash: ipfs_hash.clone()
      });

      spot_id
    }

    fn checkin_spot(ref self: ContractState, spot_id: u256) {
      assert(self.is_checkin_controller(), 'NOT_CHECKIN_CONTROLLER');

      let mut spot = self.spots.read(spot_id);

      assert(spot.ipfs_hash.len() != 0, 'SPOT_DOES_NOT_EXIST');

      let new_checkin_count = spot.checkin_count + 1;
      spot.checkin_count = new_checkin_count;
      self.spots.write(spot_id, spot);

      self.emit(SpotCheckedIn {
        spot_id,
        checkin_count: new_checkin_count
      });
    }

    fn get_spot_info(self: @ContractState, spot_id: u256) -> (u256, u256, ByteArray) {
      let spot = self.spots.read(spot_id);
      assert(spot.ipfs_hash.len() != 0, 'SPOT_DOES_NOT_EXIST');
      (spot.spot_id, spot.checkin_count, spot.ipfs_hash)
    }

    fn get_total_spots(self: @ContractState) -> u256 {
      self.total_spots.read()
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
