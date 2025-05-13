import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { parseEther, formatEther } from 'viem';
import { useContract } from '../hooks/useContract';

export default function SubmitBid({ tender, onClose }) {
  const [formData, setFormData] = useState({
    amount: '',
    proposal: ''
  });
  const [error, setError] = useState('');
  
  const { submitBid, isSubmitting } = useContract();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    try {
      // Validate the amount is not too small
      const amountNumber = parseFloat(formData.amount);
      if (amountNumber < 0.0001) {
        throw new Error('Bid amount must be at least 0.0001 USDC');
      }
      
      // Log debug information
      console.log('Submitting bid for tender:', {
        id: tender.id,
        title: tender.title,
        amount: formData.amount
      });
      
      const amountInWei = parseEther(formData.amount);

      await submitBid({
        args: [
          tender.id,  // This should be a string representation of the tender ID
          amountInWei,
          formData.proposal
        ]
      });

      onClose();
    } catch (error) {
      console.error('Error in SubmitBid component:', error);
      
      // Handle specific error cases
      if (error.code === 'ACTION_REJECTED' || 
          error.message?.includes('rejected') || 
          error.message?.includes('denied')) {
        setError('Transaction was rejected in your wallet. Please try again and confirm the transaction.');
      } else if (error.message?.includes('insufficient funds')) {
        setError('Insufficient funds in your wallet to complete this transaction.');
      } else if (error.message?.includes('OwnerCannotBid')) {
        setError('You cannot bid on your own tender.');
      } else if (error.message?.includes('BidExceedsBudget')) {
        setError('Your bid amount exceeds the tender budget.');
      } else if (error.message?.includes('TenderNotOpen')) {
        setError('This tender is no longer open for bidding.');
      } else if (error.message?.includes('DeadlinePassed')) {
        setError('The deadline for this tender has passed.');
      } else if (error.message?.includes('gas') || error.message?.includes('fee')) {
        setError('Gas estimation failed. This could be due to network congestion or an issue with your bid amount.');
      } else if (error.message?.includes('nonce')) {
        setError('Transaction nonce error. Please try refreshing the page and submitting again.');
      } else {
        // Generic error message for unhandled errors
        setError(error.message || 'Failed to submit bid. Please try again later.');
      }
    }
  };

  const handleChange = (e) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value
    }));
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="bg-slate-800 rounded-2xl p-6 w-full max-w-lg border border-white/10"
      >
        <h2 className="text-2xl font-bold text-white mb-6">
          Submit Bid
          <span className="text-sm font-normal text-gray-400 block mt-1">
            For: {tender.title}
          </span>
        </h2>
        
        {error && (
          <div className="mb-6 p-4 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400">
            {error}
          </div>
        )}
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Bid Amount (USDC)
            </label>
            <input
              type="number"
              name="amount"
              value={formData.amount}
              onChange={handleChange}
              required
              step="0.0001"
              min="0.0001"
              max={tender.budget}
              className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-xl 
                text-white placeholder-gray-500 focus:outline-none focus:ring-2 
                focus:ring-purple-500/50"
              placeholder="Min: 0.0001 USDC"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Proposal
            </label>
            <textarea
              name="proposal"
              value={formData.proposal}
              onChange={handleChange}
              required
              rows={4}
              className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-xl 
                text-white placeholder-gray-500 focus:outline-none focus:ring-2 
                focus:ring-purple-500/50"
            />
          </div>

          <div className="flex gap-4 mt-6">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 text-sm font-medium text-gray-400 
                bg-white/5 rounded-xl hover:bg-white/10 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="flex-1 px-4 py-2 text-sm font-medium text-white 
                bg-gradient-to-r from-purple-500 to-pink-500 rounded-xl
                hover:from-purple-600 hover:to-pink-600 transition-colors
                disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? 'Submitting...' : 'Submit Bid'}
            </button>
          </div>
        </form>
      </motion.div>
    </div>
  );
} 