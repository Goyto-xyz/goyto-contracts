use starknet::ContractAddress;

#[starknet::interface]
pub trait ISpotManager<TContractState> {
  fn set_checkin_controller(ref self: TContractState, checkin_controller: ContractAddress);
  fn add_spot(ref self: TContractState, ipfs_hash: ByteArray) -> u256;
  fn checkin_spot(ref self: TContractState, spot_id: u256);
  fn get_spot_info(self: @TContractState, spot_id: u256) -> (u256, u256, ByteArray);
  fn get_total_spots(self: @TContractState) -> u256;
  fn get_checkin_controller(self: @TContractState) -> ContractAddress;
}
