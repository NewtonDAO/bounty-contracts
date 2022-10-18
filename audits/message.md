# 1 Question 1 Remark
1. Regarding: answer from contract could make reward fail by putting a revert() in the receive() function.
    - If the contract deployers didn't implement their receive() function right it's dumb for them no? (They can't get paid?)
    - Is the downside for us that we lose the gas?
    - Thinking of just implementing a pull pattern instead of push. What do you think?
2. Regarding: user wasting money by answering a question that doesn't have a bountyt
    - I want all the questions and answers to be on chain (at least in the form a their hash). It excites me to think we could have a completly public, untemperable record of knowledge. 
    - We'll eat out the transactions and give users links to their transactions.
