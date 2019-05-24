pragma solidity ^0.5.8;

contract Elections {
    event VoteCasted(string message);
    
    uint constant quarantineBeforeStart = 2 minutes;
    uint constant quarantineAfterFinish = 2 minutes;
    
    string internal electionTitle;
    uint internal startDate;
    uint internal endDate;
    address internal administrator;
    
    struct Voter {
        address voterAddress;
        uint id;
        uint pollingStationId;
        bool hasVoted;
        uint LUTindex;
    }
    
    struct Candidate {
        uint candidateId;
        string name;
        uint LUTindex;
    }
    
    struct Observer {
        address observerAddress;
        uint LUTindex;
    }
    
    struct PollingStation {
        uint id;
        string title;
        mapping(uint => uint) candidateVoteCount;
        uint corruptedVoteCount;
        uint pollingStationVoterCount;
        uint LUTindex;
    }
    
    mapping(uint => PollingStation) internal pollingStations;
    mapping(address => Voter) internal voters;
    mapping(uint => Candidate) internal candidates;
    mapping(address => Observer) internal observers;
    
    mapping(uint => address) internal voterIdToAddress;
    
    uint[] internal pollingStationsLUT;
    address[] internal votersLUT;
    uint[] internal candidatesLUT;
    address[] internal observersLUT;
    
    uint internal pollingStationsCount;
    uint internal votersCount;
    uint internal candidatesCount;
    uint internal observersCount;
    
    constructor (
        uint _startDate,
        uint _endDate,
        string memory _electionTitle
    ) public payable {
        require(_startDate + quarantineBeforeStart >= now, "Start date is too early");
        require(_endDate - quarantineAfterFinish > _startDate, "Start date must be earlier than end date.");
        checkStringLength(_electionTitle, 200);
        
        startDate = _startDate;
        endDate = _endDate;
        electionTitle = _electionTitle;
        administrator = msg.sender;
    }
    
    modifier isAdministrator() {
        require(msg.sender == administrator, "You do not have administrator privilegies.");
        _;
    }
    
    modifier isVoter() {
        Voter memory voter = voters[msg.sender];
        require(voter.voterAddress == msg.sender, "You do not have voter privilegies.");
        require(voter.hasVoted == false, "Vote has already been casted.");
        _;
    }
    
    modifier isObserver() {
        require(observers[msg.sender].observerAddress == msg.sender, "You do not have observer privilegies.");
        _;
    }
    
    modifier votingInitialized() {
        uint currentDate = now;
        require(currentDate <= startDate - quarantineBeforeStart,
                "Voting initialization actions cannot be performed right now.");
        _;
    }
    
    modifier votingStarted() {
        uint currentDate = now;
        require(currentDate >= startDate && currentDate < endDate,
                "Voting is not happening right now.");
        _;
    }
    
    modifier votingFinished() {
        require(now >= endDate + quarantineAfterFinish, "Post-voting actions could not be performed right now.");
        _;
    }
    
    function checkStringLength(string memory _string, uint _byteLength) pure private {
        require(bytes(_string).length <= _byteLength, "Input string is too long.");
    }
    
    function addPollingStation(uint _id, string memory _title) isAdministrator votingInitialized public {
        checkStringLength(_title, 200);
        require(_id != 0, "Polling station ID must not be 0.");
        require(pollingStations[_id].id == 0, "Polling station already exists");
        
        pollingStations[_id] =
            PollingStation(
                {
                    id: _id,
                    title: _title,
                    corruptedVoteCount: 0,
                    pollingStationVoterCount: 0,
                    LUTindex: pollingStationsLUT.length
                });
                
        pollingStationsLUT.push(_id);
        pollingStationsCount++;
    }
    
    function setPollingStationTitle(uint _id, string memory _title) isAdministrator votingInitialized public {
        checkStringLength(_title, 200);
        require(_id != 0 && pollingStations[_id].id == _id, "Polling station does not exist.");
        pollingStations[_id].title = _title;
    }
    
    function removePollingStation(uint _id) isAdministrator votingInitialized public {
        require(_id != 0 && pollingStations[_id].id == _id, "Polling station does not exist.");
        require(pollingStations[_id].pollingStationVoterCount == 0,
                "You cannot remove polling station that has registered voters.");

        delete(pollingStationsLUT[pollingStations[_id].LUTindex]);
        delete(pollingStations[_id]);
        
        pollingStationsCount--;
    }
    
    function addVoter(address _address, uint _id, uint _pollingStationId) isAdministrator votingInitialized public {
        require(_address != address(0), "Voter address is not valid.");
        require(_id != 0, "Voter ID is not valid");
        require(voters[_address].voterAddress == address(0) &&
                voterIdToAddress[_id] == address(0), "Voter already exists.");
        
        require(_pollingStationId != 0 &&
                pollingStations[_pollingStationId].id == _pollingStationId, "Polling station does not exist.");
        
        voters[_address] =
            Voter(
                {
                    voterAddress: _address,
                    id: _id,
                    pollingStationId: _pollingStationId,
                    hasVoted: false,
                    LUTindex: votersLUT.length
                });
                
        voterIdToAddress[_id] = _address;
        votersLUT.push(_address);
        pollingStations[_pollingStationId].pollingStationVoterCount++;
        votersCount++;
    }
    
    function setVoterPollingStation(address _address, uint _pollingStationId) isAdministrator votingInitialized public {
        require(_address != address(0) &&
                voters[_address].voterAddress == _address, "Voter does not exist.");
        require(_pollingStationId != 0 &&
                pollingStations[_pollingStationId].id == _pollingStationId, "Polling station does not exist.");
        
        pollingStations[voters[_address].pollingStationId].pollingStationVoterCount--;
        voters[_address].pollingStationId = _pollingStationId;
        pollingStations[_pollingStationId].pollingStationVoterCount++;
    }
    
    function removeVoter(address _address) isAdministrator votingInitialized public {
        require(_address != address(0) &&
                voters[_address].voterAddress == _address, "Voter does not exist.");
        
        delete(votersLUT[voters[_address].LUTindex]);
        pollingStations[voters[_address].pollingStationId].pollingStationVoterCount--;
        delete(voterIdToAddress[voters[_address].id]);
        delete(voters[_address]);
        votersCount--;
    }
    
    function addCandidate(uint _id, string memory _name) isAdministrator votingInitialized public {
        checkStringLength(_name, 100);
        require(_id != 0, "Candidate address is not valid.");
        require(candidates[_id].candidateId == 0, "Candidate already exists.");
        candidates[_id] =
            Candidate(
                {
                    candidateId: _id,
                    name: _name,
                    LUTindex: candidatesLUT.length
                });
        candidatesLUT.push(_id);
        candidatesCount++;
    }
    
    function setCandidateName(uint _id, string memory _name) isAdministrator votingInitialized public {
        checkStringLength(_name, 100);
        require(_id != 0 &&
                candidates[_id].candidateId == _id, "Candidate does not exist.");

        candidates[_id].name = _name;
    }
    
    function removeCandidate(uint _id) isAdministrator votingInitialized public {
        require(_id != 0 &&
                candidates[_id].candidateId == _id, "Candidate does not exist.");
        
        delete(candidatesLUT[candidates[_id].LUTindex]);
        delete(candidates[_id]);
        candidatesCount--;
    }
    
    function addObserver(address _address) isAdministrator votingInitialized public {
        require(_address != address(0), "Observer address is not valid.");
        require(observers[_address].observerAddress == address(0), "Observer already exists.");
        
        observers[_address] =
            Observer(
                {
                    observerAddress: _address,
                    LUTindex: observersLUT.length
                });
        observersLUT.push(_address);
        observersCount++;
    }
    
    function removeObserver(address _address) isAdministrator votingInitialized public {
        require(_address != address(0) &&
                observers[_address].observerAddress == _address, "Observer does not exist.");

        delete(observersLUT[observers[_address].LUTindex]);
        delete(observers[_address]);
        observersCount--;
    }
    
    function vote(uint _candidateId) isVoter votingStarted public {
        Voter memory voter = voters[msg.sender];
        assert(voter.pollingStationId != 0 &&
               pollingStations[voter.pollingStationId].id == voter.pollingStationId);
        assert(voter.hasVoted == false);
               
        voters[voter.voterAddress].hasVoted = true;
        
        if (_candidateId != 0 && candidates[_candidateId].candidateId == _candidateId) {
            pollingStations[voter.pollingStationId].candidateVoteCount[_candidateId]++;
            emit VoteCasted(string(abi.encodePacked(
                                    "You submitted your vote for ",
                                    candidates[_candidateId].name,
                                    " (",
                                    uintToString(_candidateId),
                                    ").")));
        } else {
            pollingStations[voter.pollingStationId].corruptedVoteCount++;
            emit VoteCasted("You did not vote for any of the candidates.");
        }
    }
    
    function getCandidateList() view public returns (string memory) {
        string memory candidateList;
        
        for (uint i = 0; i < candidatesLUT.length; i++) {
            Candidate memory candidate = candidates[candidatesLUT[i]];
            
            if (candidate.candidateId == 0) {
                continue;
            }
                
            candidateList = string(abi.encodePacked(
                candidateList,
                candidate.candidateId,
                " ",
                candidate.name,
                "\x0A"));
        }
        
        return candidateList;
    }
    
    function getActivity() view public returns (uint) {
        if (votersCount == 0) {
            return 0;
        }
        
        return getVoteCount() / votersCount;
    }
    
    function getPollingStationActivity(uint _id) view public returns (uint) {
        require(_id != 0 && pollingStations[_id].id == _id, "Polling station does not exist.");
        
        if (pollingStations[_id].pollingStationVoterCount == 0) {
            return 0;
        }
        
        return getPollingStationVoteCount(_id) / pollingStations[_id].pollingStationVoterCount;
    }
    
    function getPollingStationResults(uint _id) votingFinished view public returns (string memory) {
        require(_id != 0 && pollingStations[_id].id == _id, "Polling station does not exist.");
        string memory candidateResults;
        
        for (uint i = 0; i < candidatesLUT.length; i++) {
            if (candidatesLUT[i] == 0) {
                continue;
            }
                
            candidateResults = string(abi.encodePacked(
                                        candidateResults,
                                        candidatesLUT[i],
                                        " ",
                                        candidates[candidatesLUT[i]].name,
                                        " ",
                                        uintToString(pollingStations[_id].candidateVoteCount[candidatesLUT[i]]), 
                                        "\x0A"));
        }
        
        return string(abi.encodePacked(
                        uintToString(pollingStations[_id].id),
                        " ",
                        pollingStations[_id].title,
                        "\x0A",
                        candidateResults));
    }
    
    function getResults() votingFinished view public returns (string memory) {
        string memory results;
        
        for (uint i = 0; i < candidatesLUT.length; i++) {
            if (candidatesLUT[i] == 0) {
                continue;
            }
                
            results = string(abi.encodePacked(
                            results,
                            uintToString(candidatesLUT[i]),
                            " ",
                            candidates[candidatesLUT[i]].name,
                            " vote count: ",
                            uintToString(getCandidateVoteCount(candidatesLUT[i])), 
                            "\x0A"));
        }
        
        return results;
    }
    
    function getVoteCount() view public returns (uint) {
        uint voteCount = 0;
        
        for (uint i = 0; i < pollingStationsLUT.length; i++) {
            if (pollingStationsLUT[i] == 0) {
                continue;
            }
            
            voteCount += getPollingStationVoteCount(pollingStationsLUT[i]);
        }
        
        return voteCount;
    }
    
    function getPollingStationVoteCount(uint _id) view public returns (uint) {
        require(_id != 0 && pollingStations[_id].id == _id, "Polling station does not exist.");

        uint voteCount = 0;
        
        for (uint i = 0; i < candidatesLUT.length; i++) {
            if (candidatesLUT[i] == 0) {
                continue;
            }
            
            voteCount += pollingStations[_id].candidateVoteCount[candidatesLUT[i]];
        }
        
        voteCount += pollingStations[_id].corruptedVoteCount;
        
        return voteCount;
    }
    
    function getCandidateVoteCount(uint _id) votingFinished view public returns (uint) {
        require(_id != 0 &&
                candidates[_id].candidateId == _id, "Candidate does not exist.");
                
        uint voteCount = 0;
        
        for (uint i = 0; i < pollingStationsLUT.length; i++) {
            if (pollingStationsLUT[i] == 0) {
                continue;
            }
            
            voteCount += pollingStations[pollingStationsLUT[i]].candidateVoteCount[_id];
        }
        
        return voteCount;
    }
    
    function getVoterList() isObserver view public returns (string memory) {
        string memory voterList;
        
        for (uint i = 0; i < votersLUT.length; i++) {
            Voter memory voter = voters[votersLUT[i]];
            
            if (voter.voterAddress == address(0)) {
                continue;
            }
                
            voterList = string(abi.encodePacked(
                voterList,
                uintToString(voter.id),
                " ",
                pollingStations[voter.pollingStationId].title,
                "\x0A"));
        }
        
        return voterList;
    }
    
    function uintToString(uint v) pure private returns (string memory) {
        return bytes32ToString(uintToBytes32(v));    
    }
    
    function uintToBytes32(uint v) pure private returns (bytes32 ret) {
        if (v == 0) {
            ret = '0';
        }
        else {
            while (v > 0) {
                ret = bytes32(uint(ret) / (2 ** 8));
                ret |= bytes32(((v % 10) + 48) * 2 ** (8 * 31));
                v /= 10;
            }
        }
        return ret;
    }

    function bytes32ToString (bytes32 data) pure private returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(data) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }
}