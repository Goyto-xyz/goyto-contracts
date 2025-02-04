# SpotManager
echo "Y" | \
sncast \
  verify \
  --contract-address 0x02f29eca0c192e4eaeef06ed1f385154bbe04e39534bac07f3c2a16d72e8b834 \
  --contract-name SpotManager \
  --verifier walnut \
  --network sepolia

# UserManager
echo "Y" | \
sncast \
  verify \
  --contract-address 0x05cb884f73fa25bca5a6af2be48d3b8040be70232e1d4351c6042256f3af3a89 \
  --contract-name UserManager \
  --verifier walnut \
  --network sepolia

# SpotManager
echo "Y" | \
sncast \
  verify \
  --contract-address 0x02adb9d1c995d908b5afb99de6477f0efe78a803b4d72a49415ae1c5c67bad82 \
  --contract-name CheckinController \
  --verifier walnut \
  --network sepolia
