/**
 * Formats an Ethereum address for display by truncating it
 * @param {string} address - The full Ethereum address
 * @returns {string} Truncated address (e.g., 0x1234...5678)
 */
export function formatAddress(address) {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Generates a Base name from an Ethereum address
 * @param {string} address - The full Ethereum address
 * @returns {string} A human-readable Base name
 */
export function generateBaseName(address) {
  if (!address) return '';
  
  // List of common names for generating random subject names
  const names = [
    'john', 'alex', 'sam', 'max', 'jack', 'ryan', 'mike', 'dave',
    'lisa', 'emma', 'sara', 'kate', 'amy', 'jane', 'anna', 'rose',
    'tony', 'mark', 'eric', 'luke', 'adam', 'noah', 'ben', 'leo',
    'zoe', 'ruby', 'mia', 'eva', 'cora', 'ivy', 'lily', 'maya'
  ];
  
  // Create deterministic selection based on the address
  const addressLower = address.toLowerCase();
  
  // Use part of the address to select a name
  const nameIndex = parseInt(addressLower.slice(2, 10), 16) % names.length;
  
  // Format the name as subject.base.eth
  return `${names[nameIndex]}.base.eth`;
} 