use starknet::ContractAddress;

#[starknet::interface]
pub trait ICheckinController<TContractState> {
  fn add_spot(ref self: TContractState, ipfs_hash: ByteArray);
  fn checkin(ref self: TContractState, spot_id: u256, with_media: bool, friend_count: u256, ipfs_hash: ByteArray);
  fn get_spot_manager(self: @TContractState) -> ContractAddress;
  fn get_user_manager(self: @TContractState) -> ContractAddress;
  fn get_checkin_history(self: @TContractState, user: ContractAddress) -> Array<(u256, u256, u64, ByteArray)>;
}
