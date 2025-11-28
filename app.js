// App.js - Basic voting interface (integrates with SpireKey via deep link)
import React, { useState } from 'react';
import { useKadenaSigner } from '@kadena/react-components'; // or your SpireKey hook

function App() {
  const [proposalId, setProposalId] = useState('');
  const [choice, setChoice] = useState('yes');
  const [amount, setAmount] = useState(100);
  const signer = useKadenaSigner(); // SpireKey integration

  const handleVote = async () => {
    // 1. Deep link to SpireKey for FaceID sign
    const { jwt } = await window.SpireKey.requestAuth(); // Pseudo-code; use actual deep link
    
    // 2. Call Pact
    const tx = await signer.signAndSubmit({
      code: `(spirekey-dao-voting.cast-vote "${proposalId}" "${choice}" ${amount} "${jwt}")`,
      networkId: 'testnet04', // or mainnet01
      chainId: '1'
    });
    console.log('Vote submitted:', tx);
  };

  return (
    <div>
      <h1>SpireKey Conviction DAO Vote</h1>
      <input placeholder="Proposal ID" value={proposalId} onChange={e => setProposalId(e.target.value)} />
      <select value={choice} onChange={e => setChoice(e.target.value)}>
        <option value="yes">Yes</option>
        <option value="no">No</option>
        <option value="neutral">Neutral</option>
      </select>
      <input type="number" placeholder="KDA to Lock" value={amount} onChange={e => setAmount(e.target.value)} />
      <button onClick={handleVote}>Vote (FaceID Required)</button>
    </div>
  );
}

export default App;