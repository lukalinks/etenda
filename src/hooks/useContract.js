import { useEffect, useState } from 'react';
import { ethers } from 'ethers';
import { tenderABI } from '../constants/abis';

export function useContract() {
  const [contract, setContract] = useState(null);
  const [error, setError] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [userBids, setUserBids] = useState([]);
  const [isUserBidsLoading, setIsUserBidsLoading] = useState(false);
  const contractAddress = import.meta.env.VITE_CONTRACT_ADDRESS;

  useEffect(() => {
    const initContract = async () => {
      try {
        if (!window.ethereum) {
          throw new Error('No Web3 provider found');
        }

        if (!contractAddress) {
          throw new Error('Contract address not configured');
        }

        // Request account access
        await window.ethereum.request({ method: 'eth_requestAccounts' });
        
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const signer = provider.getSigner();
        
        // Get the network to verify connection
        const network = await provider.getNetwork();
        console.log('Connected to network:', network);

        const tenderContract = new ethers.Contract(
          contractAddress,
          tenderABI,
          signer
        );

        // Log available functions
        console.log('Available contract functions:', Object.keys(tenderContract.functions));
        
        setContract(tenderContract);
        setError(null);
      } catch (err) {
        console.error('Contract initialization error:', err);
        setError(err.message);
        setContract(null);
      }
    };

    initContract();

    if (window.ethereum) {
      window.ethereum.on('accountsChanged', initContract);
      window.ethereum.on('chainChanged', initContract);
      
      return () => {
        window.ethereum.removeListener('accountsChanged', initContract);
        window.ethereum.removeListener('chainChanged', initContract);
      };
    }
  }, [contractAddress]);

  // Load user bids when contract is available
  useEffect(() => {
    const loadUserBids = async () => {
      if (!contract) return;
      
      try {
        setIsUserBidsLoading(true);
        
        // Get the current user's address
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const signer = provider.getSigner();
        const address = await signer.getAddress();
        
        // Get user's bids from contract
        const bids = await contract.getUserBids(address);
        console.log('User bids from contract:', bids);
        
        setUserBids(bids);
      } catch (err) {
        console.error('Error loading user bids:', err);
        setUserBids([]);
      } finally {
        setIsUserBidsLoading(false);
      }
    };
    
    loadUserBids();
  }, [contract]);

  const getRecentTenders = async (limit = 10) => {
    try {
      if (!contract) throw new Error("Contract not initialized");
      const tenders = await contract.getRecentTenders(limit);
      return tenders;
    } catch (error) {
      console.error("Error getting recent tenders:", error);
      throw error;
    }
  };

  const postTender = async ({ title, description, budget, deadline }) => {
    try {
      if (!contract) {
        throw new Error('Contract not initialized. Please check your wallet connection.');
      }

      if (!title || !description || !budget || !deadline) {
        throw new Error('All fields are required');
      }

      const budgetInWei = ethers.utils.parseEther(budget.toString());
      const deadlineTimestamp = Math.floor(new Date(deadline).getTime() / 1000);

      const tx = await contract.postTender(
        title,
        description,
        budgetInWei,
        deadlineTimestamp,
        { gasLimit: 500000 }
      );
      
      const receipt = await tx.wait();
      return receipt;
    } catch (error) {
      console.error('Error posting tender:', error);
      throw error;
    }
  };

  const submitBid = async ({ args }) => {
    try {
      setIsSubmitting(true);
      
      if (!contract) {
        throw new Error('Contract not initialized. Please check your wallet connection.');
      }

      const [tenderId, amount, proposal] = args;
      
      if (!tenderId || !amount || !proposal) {
        throw new Error('All bid fields are required');
      }

      // Ensure the amount meets minimum requirements
      if (ethers.utils.formatEther(amount) < 0.0001) {
        throw new Error('Bid amount must be at least 0.0001 USDC');
      }

      // Debug the contract interaction
      console.log('Submitting bid with args:', {
        tenderId: tenderId.toString(),
        amount: amount.toString(),
        proposal
      });
      
      try {
        const tx = await contract.submitBid(
          tenderId,
          amount,
          proposal,
          { gasLimit: 500000 }
        );
        
        console.log('Transaction submitted:', tx.hash);
        
        try {
          const receipt = await tx.wait();
          console.log('Bid submitted successfully:', receipt);
          
          // Refresh user bids after successful submission
          const provider = new ethers.providers.Web3Provider(window.ethereum);
          const signer = provider.getSigner();
          const address = await signer.getAddress();
          const bids = await contract.getUserBids(address);
          setUserBids(bids);
          
          return receipt;
        } catch (waitError) {
          console.error('Error waiting for transaction:', waitError);
          
          // Check if transaction was rejected by the network
          if (waitError.code === 'TRANSACTION_REPLACED') {
            if (waitError.cancelled) {
              throw new Error('Transaction was cancelled. It may have been rejected by the network.');
            } else {
              // Transaction was replaced/accelerated but not cancelled
              console.log('Transaction was replaced:', waitError.replacement);
              return waitError.receipt || waitError.replacement.receipt;
            }
          }
          
          throw waitError;
        }
      } catch (txError) {
        console.error('Transaction error:', txError);
        
        // Handle user rejection explicitly
        if (txError.code === 'ACTION_REJECTED') {
          const error = new Error('Transaction was rejected in your wallet');
          error.code = 'ACTION_REJECTED';
          throw error;
        }
        
        // Process specific contract errors for more user-friendly messages
        if (txError.code === 'CALL_EXCEPTION') {
          if (txError.message.includes('OwnerCannotBid')) {
            throw new Error('You cannot bid on your own tender');
          } else if (txError.message.includes('BidExceedsBudget')) {
            throw new Error('Bid amount exceeds the tender budget');
          } else if (txError.message.includes('TenderNotOpen')) {
            throw new Error('This tender is no longer open for bidding');
          } else if (txError.message.includes('DeadlinePassed')) {
            throw new Error('The deadline for this tender has passed');
          }
        }
        
        // Pass through any other errors
        throw txError;
      }
    } catch (error) {
      console.error('Final error in submitBid:', error);
      throw error;
    } finally {
      setIsSubmitting(false);
    }
  };

  return {
    contract,
    error,
    postTender,
    getRecentTenders,
    submitBid,
    userBids,
    isUserBidsLoading,
    isSubmitting,
    isInitialized: !!contract,
    contractAddress
  };
} 