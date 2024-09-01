// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Define the smart contract named 'Tracking'
contract SupplyChain {
    // Define an enumeration to represent the different statuses a shipment can have
    enum ShipmentStatus {
        PENDING,      // Shipment has been created but not yet started
        IN_TRANSIT,   // Shipment is currently in transit
        CANCELLED,    // Shipment has been cancelled
        DELIVERED     // Shipment has been delivered
    }

    // Define a struct to represent a Shipment
    struct Shipment {
        address sender;           // Address of the sender
        address receiver;         // Address of the receiver
        uint256 pickupTime;       // Timestamp when the shipment was picked up
        uint256 deliveryTime;     // Timestamp when the shipment was delivered
        uint256 distance;         // Distance of the shipment
        uint256 price;            // Price of the shipment
        ShipmentStatus status;    // Current status of the shipment
        bool isPaid;              // Indicates if the shipment has been paid for
    }

    // Mapping from sender address to an array of their Shipments
    mapping(address => Shipment[]) public shipments;

    // Total count of shipments created
    uint256 public shipmentCount;

    // Define another struct 'TypeShipment' (seems redundant; possibly for extended functionality)
    struct TypeShipment {
        address sender;
        address receiver;
        uint256 pickupTime;
        uint256 deliveryTime;
        uint256 distance;
        uint256 price;
        ShipmentStatus status;
        bool isPaid;
    }

    // Array to store all TypeShipments
    TypeShipment[] typeShipments;

    // Define events to emit during different stages of shipment lifecycle
    event ShipmentCreated(
        address indexed sender,
        address indexed receiver,
        uint256 pickupTime,
        uint256 distance,
        uint256 price
    );

    event ShipmentInTransit(
        address indexed sender,
        address indexed receiver,
        uint256 pickupTime
    );

    event ShipmentDelivered(
        address indexed sender,
        address indexed receiver,
        uint256 deliveryTime
    );

    event ShipmentPaid(
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );

    event ShipmentCancelled(
        address indexed sender,
        address indexed receiver,
        uint256 indexed index,
        uint256 amount
    );

    // Constructor to initialize the shipment count
    constructor() {
        shipmentCount = 0;
    }

    /**
     * @dev Creates a new shipment.
     * @param _receiver The address of the receiver.
     * @param _pickupTime The timestamp when the shipment is picked up.
     * @param _distance The distance of the shipment.
     * @param _price The price of the shipment.
     */
    function createShipment(
        address _receiver,
        uint256 _pickupTime,
        uint256 _distance,
        uint256 _price
    ) public payable {
        // Ensure the sent Ether matches the price of the shipment
        require(msg.value == _price, "Payment amount must match the price");

        // Create a new Shipment struct in memory
        Shipment memory shipment = Shipment(
            msg.sender,
            _receiver,
            _pickupTime,
            0, // deliveryTime is initially zero
            _distance,
            _price,
            ShipmentStatus.PENDING,
            false // isPaid is initially false
        );

        // Add the shipment to the sender's array of shipments
        shipments[msg.sender].push(shipment);
        shipmentCount++;

        // Add the shipment to the global typeShipments array
        typeShipments.push(
            TypeShipment(
                msg.sender,
                _receiver,
                _pickupTime,
                0,
                _distance,
                _price,
                ShipmentStatus.PENDING,
                false
            )
        );

        // Emit the ShipmentCreated event
        emit ShipmentCreated(msg.sender, _receiver, _pickupTime, _distance, _price);
    }

    /**
     * @dev Marks a shipment as in transit.
     * @param _sender The address of the sender.
     * @param _receiver The address of the receiver.
     * @param _index The index of the shipment in the sender's shipment array.
     */
    function startShipment(address _sender, address _receiver, uint256 _index) public {
        // Retrieve the shipment from the sender's shipments
        Shipment storage shipment = shipments[_sender][_index];
        // Retrieve the corresponding TypeShipment
        TypeShipment storage typeShipment = typeShipments[_index];

        // Validate the receiver address
        require(shipment.receiver == _receiver, "Invalid receiver");
        // Ensure the shipment is in the PENDING state
        require(shipment.status == ShipmentStatus.PENDING, "Shipment already not in pending");

        // Update the status to IN_TRANSIT
        shipment.status = ShipmentStatus.IN_TRANSIT;
        typeShipment.status = ShipmentStatus.IN_TRANSIT;

        // Emit the ShipmentInTransit event
        emit ShipmentInTransit(_sender, _receiver, shipment.pickupTime);
    }

    /**
     * @dev Cancels a shipment and refunds the sender.
     * @param _sender The address of the sender.
     * @param _receiver The address of the receiver.
     * @param _index The index of the shipment in the sender's shipment array.
     */
    function cancelShipment(address _sender, address _receiver, uint256 _index) public {
        // Retrieve the shipment from the sender's shipments
        Shipment storage shipment = shipments[_sender][_index];
        // Retrieve the corresponding TypeShipment
        TypeShipment storage typeShipment = typeShipments[_index];

        // Ensure that the caller is the sender of the shipment
        require(_sender == shipment.sender, "Only the sender can close the shipment");
        // Validate the receiver address
        require(_receiver == shipment.receiver, "Wrong receiver entered");
        // Ensure the shipment hasn't been delivered yet
        require(shipment.status != ShipmentStatus.DELIVERED, "Shipment is already delivered");

        // Reset the pickupTime
        shipment.pickupTime = 0;
        typeShipment.pickupTime = 0;
        // Update the status to CANCELLED
        shipment.status = ShipmentStatus.CANCELLED;
        typeShipment.status = ShipmentStatus.CANCELLED;

        // Retrieve the price to refund
        uint256 amount = shipment.price;

        // Refund the sender
        payable(shipment.sender).transfer(amount);

        // Emit the ShipmentCancelled event
        emit ShipmentCancelled(_sender, _receiver, _index, amount);
    }

    /**
     * @dev Completes a shipment and transfers the payment to the receiver.
     * @param _sender The address of the sender.
     * @param _receiver The address of the receiver.
     * @param _index The index of the shipment in the sender's shipment array.
     */
    function completeShipment(address _sender, address _receiver, uint256 _index) public {
        // Retrieve the shipment from the sender's shipments
        Shipment storage shipment = shipments[_sender][_index];
        // Retrieve the corresponding TypeShipment
        TypeShipment storage typeShipment = typeShipments[_index];

        // Validate the receiver address
        require(shipment.receiver == _receiver, "Invalid receiver");
        // Ensure the shipment is currently in transit
        require(shipment.status == ShipmentStatus.IN_TRANSIT, "Shipment not in transit");
        // Ensure the shipment hasn't been paid for yet
        require(!shipment.isPaid, "Shipment already paid.");

        // Update the status to DELIVERED
        shipment.status = ShipmentStatus.DELIVERED;
        typeShipment.status = ShipmentStatus.DELIVERED;
        // Set the delivery time to the current block timestamp
        typeShipment.deliveryTime = block.timestamp;
        shipment.deliveryTime = block.timestamp;

        // Retrieve the price to transfer to the receiver
        uint256 amount = shipment.price;

        // Transfer the payment to the receiver
        payable(shipment.receiver).transfer(amount);

        // Mark the shipment as paid
        shipment.isPaid = true;
        typeShipment.isPaid = true;

        // Emit the ShipmentDelivered and ShipmentPaid events
        emit ShipmentDelivered(_sender, _receiver, shipment.deliveryTime);
        emit ShipmentPaid(_sender, _receiver, amount);
    }

    /**
     * @dev Retrieves the details of a specific shipment.
     * @param _sender The address of the sender.
     * @param _index The index of the shipment in the sender's shipment array.
     * @return A tuple containing all details of the shipment.
     */
    function getShipment(
        address _sender,
        uint256 _index
    )
        public
        view
        returns (
            address,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            ShipmentStatus,
            bool
        )
    {
        // Retrieve the shipment from the sender's shipments
        Shipment memory shipment = shipments[_sender][_index];
        // Return all details of the shipment
        return (
            shipment.sender,
            shipment.receiver,
            shipment.pickupTime,
            shipment.deliveryTime,
            shipment.distance,
            shipment.price,
            shipment.status,
            shipment.isPaid
        );
    }

    /**
     * @dev Retrieves the number of shipments created by a specific sender.
     * @param _sender The address of the sender.
     * @return The number of shipments the sender has created.
     */
    function getShipmentCount(address _sender) public view returns (uint256) {
        return shipments[_sender].length;
    }

    /**
     * @dev Retrieves all TypeShipment transactions.
     * @return An array of all TypeShipments.
     */
    function getAllTransactions() public view returns (TypeShipment[] memory) {
        return typeShipments;
    }
}