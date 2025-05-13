import { useState, useEffect } from 'react';
import { useContract } from '../hooks/useContract';
import { formatEther } from 'viem';
import SubmitBid from './SubmitBid';
import { formatAddress, generateBaseName } from '../lib/addressUtils';

export default function TenderList() {
  const [tenders, setTenders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const { contract, error: contractError } = useContract();
  const [selectedTender, setSelectedTender] = useState(null);

  useEffect(() => {
    if (contract) {
      fetchTenders();
    } else if (contractError) {
      setError(`Contract Error: ${contractError}`);
      setLoading(false);
    }
  }, [contract, contractError]);

  const fetchTenders = async () => {
    try {
      setLoading(true);
      setError(null);

      if (!contract) throw new Error("Contract not initialized");

      // Get recent tenders directly using the getRecentTenders function
      const tenderList = await contract.getRecentTenders(10);

      console.log('Raw tender data:', tenderList);

      const formattedTenders = tenderList.map(tender => {
        // Create a properly formatted tender object
        return {
          id: tender.id.toString(),
          title: tender.title,
          description: tender.description,
          rawBudget: tender.budget, // Keep the raw budget value for the bid form
          budget: formatEther(tender.budget),
          deadline: new Date(Number(tender.deadline) * 1000).toLocaleString(),
          status: getStatusText(tender.status),
          owner: tender.owner,
          ownerFormatted: formatAddress(tender.owner),
          ownerBaseName: generateBaseName(tender.owner)
        };
      });

      console.log('Formatted tenders:', formattedTenders);
      setTenders(formattedTenders);
    } catch (error) {
      console.error('Error fetching tenders:', error);
      setError(`Failed to load tenders: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const getStatusText = (status) => {
    switch (Number(status)) {
      case 0:
        return 'Open';
      case 1:
        return 'Closed';
      case 2:
        return 'Awarded';
      default:
        return 'Unknown';
    }
  };

  const handleBidClick = (tender) => {
    setSelectedTender(tender);
  };

  const handleCloseModal = () => {
    setSelectedTender(null);
    fetchTenders(); // Refresh tenders after bid submission
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[200px]">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-500"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-red-500">{error}</p>
        <button 
          onClick={fetchTenders}
          className="mt-4 px-4 py-2 bg-purple-500 text-white rounded-lg hover:bg-purple-600"
        >
          Try Again
        </button>
      </div>
    );
  }

  return (
    <div className="tender-list">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold">Listed Tenders</h2>
        <button 
          onClick={fetchTenders}
          className="px-4 py-2 text-sm bg-purple-500 text-white rounded-lg hover:bg-purple-600"
        >
          Refresh
        </button>
      </div>

      {tenders.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500">No tenders found</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {tenders.map((tender) => (
            <div key={tender.id} className="bg-slate-800 rounded-xl p-6 border border-white/10">
              <h3 className="text-xl font-bold text-white mb-2">{tender.title}</h3>
              <p className="text-gray-400 mb-4 line-clamp-2">{tender.description}</p>
              
              <div className="space-y-3">
                <div className="flex justify-between items-center text-sm">
                  <span className="text-gray-400">Budget</span>
                  <span className="text-white font-medium">{tender.budget} USDC</span>
                </div>

                <div className="flex justify-between items-center text-sm">
                  <span className="text-gray-400">Deadline</span>
                  <span className="text-white font-medium">{tender.deadline}</span>
                </div>

                <div className="flex justify-between items-center text-sm">
                  <span className="text-gray-400">Status</span>
                  <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                    tender.status === 'Open' ? 'bg-green-500/10 text-green-400' :
                    tender.status === 'Closed' ? 'bg-red-500/10 text-red-400' :
                    'bg-blue-500/10 text-blue-400'
                  }`}>
                    {tender.status}
                  </span>
                </div>

                <div className="pt-3 border-t border-white/10">
                  <div className="flex flex-col">
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium text-gray-400">Owner:</span>
                      <span className="text-sm text-white font-mono">{tender.ownerFormatted}</span>
                    </div>
                    <div className="flex justify-between items-center mt-1">
                      <span className="text-sm font-medium text-gray-400">Base Name:</span>
                      <span className="text-sm text-purple-400 font-medium">{tender.ownerBaseName}</span>
                    </div>
                  </div>
                </div>

                {tender.status === 'Open' && (
                  <div className="pt-3">
                    <button
                      onClick={() => handleBidClick(tender)}
                      className="w-full py-2 px-4 bg-gradient-to-r from-purple-500 to-pink-500 
                        text-white font-medium rounded-lg hover:from-purple-600 
                        hover:to-pink-600 transition-colors"
                    >
                      Place Bid
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {selectedTender && (
        <SubmitBid tender={selectedTender} onClose={handleCloseModal} />
      )}
    </div>
  );
} 