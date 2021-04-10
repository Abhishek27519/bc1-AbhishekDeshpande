pragma solidity ^0.8.0;

interface Product_Trace{
    function getHashes(uint _id) external view returns(bytes32);
}

contract Trace{
    
    enum State{Registered, Waiting, InTransit, Delivered, Returned, Cancelled}
    
    struct Consignment{
        uint consignment_id;
        address sender;
        address receiver;
        bytes32 product_hash;
        uint from_hub;
        uint to_hub;
        uint next_hub;
        uint registered_date;
        uint expected_arrival_date;
        uint dispatched_date;
        uint received_date;
        uint[] hubs_hoped;
        uint state;
    }
    mapping(uint=>Consignment) public consignments;
    uint public consignment_counter;
    
    ProductManagement public products;
    
    struct Hub{
        address manager;
        uint location;
        string name;
        uint[] consignment_dispatched;
        uint[] consignment_received;
        uint[] consignment_hoped;
        uint[] consignment_waiting;
    }
    mapping(uint=>Hub) public hubs;
    mapping(address=>uint) public manager_to_hub;
    
    mapping(address=>uint[]) public sender_consignments;
    
    constructor (address _address) public {
        products = ProductManagement(_address);
    }
    
    modifier requireHub(uint _from, uint _to) {
        require(hubs[_from].location != 0 && hubs[_from].location != 0, "Hub does not exists" );
        _;
    }
    
    modifier requireDiffHub(uint _from, uint _to) {
        require(_from != _to, "Unecessary Dispatch");
        _;
    }
    
    
    // Function Declarations
    function registerConsignment(address _receiver, uint _product, uint _from, uint _to, uint _expected_delivery ) requireHub(_from, _to) requireDiffHub(_from, _to) public {
        consignment_counter++;
        consignments[consignment_counter].consignment_id = consignment_counter;
        consignments[consignment_counter].sender = msg.sender;
        consignments[consignment_counter].product_hash = products.getHashes(_product);
        consignments[consignment_counter].from_hub = _from;
        consignments[consignment_counter].to_hub = _to;
        consignments[consignment_counter].registered_date = block.timestamp;
        consignments[consignment_counter].receiver = _receiver;
        
        require(_expected_delivery > block.timestamp, "You cannot deliver a product in past");
        
        consignments[consignment_counter].expected_arrival_date = _expected_delivery;
        consignments[consignment_counter].state = uint(State.Registered);
        consignments[consignment_counter].hubs_hoped.push(_from);
        
        
        sender_consignments[msg.sender].push(consignment_counter);
        
        hubs[_from].consignment_waiting.push(consignment_counter);
    }
    
    modifier uniqueHub(uint _location){
        require(hubs[_location].manager == address(0) && manager_to_hub[msg.sender]==0, "Hub already exist");
        _;
    }
    
    function registerHub(uint _location, string memory _name) public uniqueHub(_location) {
        hubs[_location].manager = msg.sender;
        hubs[_location].location = _location;
        hubs[_location].name = _name;
        manager_to_hub[msg.sender] = _location;
    }
    
    function cancelConsignment(uint id) public {
        require(consignments[id].state!=uint(State.Delivered),"Already Delivered");
        consignments[id].state = uint(State.Cancelled);
    }
    
    modifier requireWaiting(uint _consignment_id) {
        uint[] memory cw = hubs[manager_to_hub[msg.sender]].consignment_waiting;
        uint flag;
        for(uint i; i<cw.length ;i++){
            if(cw[i]==_consignment_id){
                flag = 1;
            }
        }
        require(flag==1,"You cannot Disptach consignment which you don't have");
        _;
    }
    
    modifier requireDiffNextHub(uint _next_hub) {
        require(_next_hub != manager_to_hub[msg.sender],"You cannot dispatch it to yourselves");
        _;
    }
    function dispatch(uint _consignment_id, uint _next_hub) public requireWaiting(_consignment_id) {
        consignments[_consignment_id].next_hub = _next_hub;
        consignments[_consignment_id].state = uint(State.InTransit);
        if(hubs[consignments[_consignment_id].from_hub].manager==msg.sender){
            consignments[_consignment_id].dispatched_date = block.timestamp;
            hubs[manager_to_hub[msg.sender]].consignment_dispatched.push(_consignment_id);
            }
            else{
                hubs[manager_to_hub[msg.sender]].consignment_hoped.push(_consignment_id);
            }
            uint[] memory cw = hubs[manager_to_hub[msg.sender]].consignment_waiting;
                for(uint i = 0; i<cw.length; i++){
                    if(cw[i] == _consignment_id){
                    delete hubs[manager_to_hub[msg.sender]].consignment_waiting[i];
                }
        }
    }
    
    modifier requireIncoming(uint _consignment_id) {
        require(consignments[_consignment_id].next_hub==manager_to_hub[msg.sender],"You cannot receive this consignment");
        _;
    }
    
    function received(uint _consignment_id) public requireIncoming(_consignment_id) {
        consignments[_consignment_id].hubs_hoped.push(manager_to_hub[msg.sender]);
        consignments[_consignment_id].state = uint(State.Waiting);
        if(consignments[_consignment_id].to_hub == manager_to_hub[msg.sender]){
            delivered(_consignment_id);
        }else{
            hubs[manager_to_hub[msg.sender]].consignment_waiting.push(_consignment_id);
        }
    }
    
    modifier requireDestination(uint _consignment_id) {
        require(consignments[_consignment_id].to_hub==manager_to_hub[msg.sender],"You cannot receive this consignment");
        _;
    }
    
    function delivered(uint _consignment_id) public requireDestination(_consignment_id) {
        uint curr_hub = manager_to_hub[msg.sender];
        consignments[_consignment_id].next_hub = 0;
        consignments[_consignment_id].received_date = block.timestamp;
        consignments[_consignment_id].state = uint(State.Delivered);
        hubs[curr_hub].consignment_received.push(_consignment_id);
    }
    
    function getStatus(uint _consignment_id) public view returns(Consignment memory) {
        return consignments[_consignment_id];
    }
    
    function getMyConsignments() public view returns(uint[] memory) {
        return sender_consignments[msg.sender];
    }
    
    function getConsignmentHoped(uint _id) public view returns(uint[] memory hoped, uint[] memory _received, uint[] memory dispatched, uint[] memory waiting){
        return (hubs[_id].consignment_hoped, hubs[_id].consignment_received, hubs[_id].consignment_dispatched, hubs[_id].consignment_waiting);
    }
    
    function getHubHoped(uint _id) public view returns(uint[] memory){
        return consignments[_id].hubs_hoped;
    }
    
}