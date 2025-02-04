import fs from "fs";
import dotenv from "dotenv";
import { RpcProvider, Contract, json, Account } from "starknet";

dotenv.config({ path: "../.env" });

const provider = new RpcProvider({
  nodeUrl: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7",
});

const contractAddress =
  "0x02adb9d1c995d908b5afb99de6477f0efe78a803b4d72a49415ae1c5c67bad82";
const abi = json.parse(
  fs.readFileSync("../abi/checkin_controller.json").toString("ascii")
);

const checkinController = new Contract(abi, contractAddress, provider);

const accountAddress =
  "0x024c5cD45110922b359fe561665d8f9d898cdB1DC7dDd660Ed1cf03e26C36605";
const account = new Account(provider, accountAddress, process.env.PRIVATE_KEY);

checkinController.connect(account);

const call = checkinController.populate("checkin", [
  0,
  true,
  0,
  "checkin_ipfs_hash",
]);
const response = await checkinController.checkin(call.calldata);

await provider.waitForTransaction(response.transaction_hash);

console.log("✅ Checkedin!", response.transaction_hash);
