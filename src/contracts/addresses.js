// Network IDs
export const NETWORK_IDS = {
  BASE_MAINNET: 8453,
  BASE_SEPOLIA: 84532,
};

// Contract addresses for different networks
export const CONTRACT_ADDRESSES = {
  [NETWORK_IDS.BASE_MAINNET]: '0x54dada9778e511291f41858be89a23a0d3eaec22',
  [NETWORK_IDS.BASE_SEPOLIA]: '0x7e767A270111a8957FCc69ee3ea95bD0c9F67708',
};

// Get contract address by network ID
export function getContractAddress(networkId) {
  return CONTRACT_ADDRESSES[networkId] || null;
} 