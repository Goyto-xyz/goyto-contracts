use starknet::ContractAddress;

#[starknet::interface]
pub trait IUserManager<TContractState> {
  fn set_checkin_controller(ref self: TContractState, checkin_controller: ContractAddress);
  fn update_user_points(ref self: TContractState, user: ContractAddress, points: u256, sub_points: u256);
  fn update_user_checkin(ref self: TContractState, user: ContractAddress, spot_id: u256);
  fn update_user_spot_added(ref self: TContractState, user: ContractAddress, spot_id: u256);
  fn get_user_info(self: @TContractState, user: ContractAddress) -> (u256, u256, u256);
  fn get_checkin_controller(self: @TContractState) -> ContractAddress;
}
