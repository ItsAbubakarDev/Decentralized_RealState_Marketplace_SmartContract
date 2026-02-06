// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract realState {

    //State variables State variables are variables declared at the contract level. 
    //They are stored permanently on the blockchain and represent the contract's state.
    //Stored in contract storage (persistent across transactions).
    //Changing a state variable costs gas.
    //Accessible by all functions within the contract (subject to visibility).
    //retain the value between function call 

    //STATE VARIABLES

    struct Property{
        uint256 propertyID;
        address owner;
        uint256 price;
        string propertyTitle;
        string category;
        string image;
        string propertyAddress;
        string description;
        address[] reviewers;
        string[] reviews;
    }

    //Mapping (map one property with unique id)
    mapping(uint256 => Property) private properties;

    //variable for the property id 
    uint256 public propertyIndex;

    //Events (An event is a way for a smart contract to emit logs that are stored in the transaction receipt, not in contract storage.)

    event propertyListed(uint256 indexed id, address indexed owner, uint256 price);

    event propertySold(uint256 indexed id, address indexed oldOwner, address indexed newOwner, uint256 price);

    event propertyResold(uint256 indexed id, address indexed oldOwner, address indexed newOwner, uint256 price);

    // REVIEW SECTION 

    struct review {
        address reviewer;
        uint256 productId;
        uint8 rating;
        string comment;
        uint256 likes; 
    }

    struct product{
        uint256 productId;
        uint256 totalRating;
        uint256 numberOfReviews;
    }

    //write the mapping for reviews 
    //every review has a unique id and when we map it we get the review details
    mapping(uint256 => review[]) private reviews;

    //FIXED: Changed to array to store all property IDs that user has reviewed
    //we have done this because the user will have its own dashboard where he can see all his reviews and all other activities
    mapping(address => uint256[]) private userReviewedProperties;

    mapping(uint256 => product) private products;

    uint256 public reviewsCounter;

    //Creating events for reviews

    event reviewAdded(uint indexed productId, address indexed reviewer, uint8 rating, string comment);
    event reviewLiked(uint256 indexed productId, uint256 indexed reviewId, address indexed liker, uint256 totalLikes);

    //Functions in the contract
    // underscore(_) is just for naming conversion to distinguish parameters from state variables
    function listProperty(address owner, uint256 price, string memory _propertyTitle, string memory _category, string memory _propertyAddress, string memory _propertyDescription, string memory _image) external returns(uint256){
        require(price > 0, "Price must be greater than zero");
        uint256 propertyId = propertyIndex++;
        // the storage data type lives permanently on the Blockchain
        Property storage newProperty = properties[propertyId];
        newProperty.propertyID = propertyId;
        newProperty.owner = owner;        newProperty.price = price;
        newProperty.propertyTitle = _propertyTitle;
        newProperty.propertyAddress = _propertyAddress;
        newProperty.category = _category;
        newProperty.image = _image;
        newProperty.description = _propertyDescription;

        emit propertyListed(propertyId, owner, price);
        return propertyId;
    }

    function updateProperty(address owner, uint256 propertyId, string memory _propertyTitle, string memory _propertyAddress, string memory _propertyDescription, string memory _category, string memory _image) external returns(uint256){
        //extracting the specific property from the properties array by the propertyId
        Property storage existingProperty = properties[propertyId];
        require(existingProperty.owner == owner, "Only the owner can update the property");
        existingProperty.propertyTitle = _propertyTitle;
        existingProperty.propertyAddress = _propertyAddress;
        existingProperty.description = _propertyDescription;
        existingProperty.category = _category;
        existingProperty.image = _image;
        return propertyId;
    }

    function updatePriceOfProperty(address owner, uint256 propertyId, uint256 newPrice) external returns(string memory){
        Property storage existingProperty = properties[propertyId];
        require(existingProperty.owner == owner, "Only owner can update the price");
        require(newPrice > 0, "Price must be greater than zero");
        existingProperty.price = newPrice;
        return "Price updated successfully";
    }

    //msg.value is a global variable that contains the amount of Wei (smallest unit of Ether) sent in the current transaction.
    function buyProperty(uint256 propertyId, address buyer) external payable{
        Property storage existingProperty = properties[propertyId];
        require(msg.value >= existingProperty.price, "Insufficient funds to buy this property");
        address oldOwner = existingProperty.owner;
        existingProperty.owner = buyer;
        //transfer the funds to the old owner and take a commision of 2 percent 
        uint256 commission = (msg.value * 2) / 100;
        uint256 sellerAmount = msg.value - commission;
        payable(oldOwner).transfer(sellerAmount);
        emit propertySold(propertyId, oldOwner, buyer, existingProperty.price);    
    }

    function getAllProperty() external view returns(Property[] memory){
        uint256 propertyCount = propertyIndex;
        uint256 currentIndex = 0;
        Property[] memory allProperties = new Property[](propertyIndex);
        for (uint256 i = 0; i < propertyCount; i++){
            Property storage currentProperty = properties[i];
            allProperties[currentIndex] = currentProperty;
            currentIndex += 1;
        }
        return allProperties;
    }

    //to get individual property
    function getProperty(uint256 propertyId) external view returns(uint256, address, string memory, string memory, string memory, string memory, string memory){
        Property memory property = properties[propertyId];
        return (property.propertyID, property.owner, property.propertyTitle, property.propertyAddress, property.description, property.category, property.image);
    }

    function getUserProperty(address user) external view returns (Property[] memory) {
        uint256 propertyCount = propertyIndex;
        uint256 userPropertyCount = 0;

        // 1. Count user's properties
        for (uint256 i = 0; i < propertyCount; i++) {
            if (properties[i].owner == user) {
                userPropertyCount++;
            }
        }

        // 2. Create memory array with exact size
        Property[] memory userProperties = new Property[](userPropertyCount);
        uint256 currentIndex = 0;

        // 3. Populate array
        for (uint256 i = 0; i < propertyCount; i++) {
            if (properties[i].owner == user) {
                userProperties[currentIndex] = properties[i];
                currentIndex++;
            }
        }

        return userProperties;
    }

    //Reviews
    //FIXED: Reordered parameters for better convention (propertyId, rating, comment, reviewer)
    function addReview(uint256 propertyId, uint256 rating, string calldata comment, address reviewer) external {
        require(rating >= 1 && rating <= 5, "Rating should be between 1 and 5");
        Property storage property = properties[propertyId];
        property.reviewers.push(reviewer);
        property.reviews.push(comment);

        //Review Section mapping the review details
        reviews[propertyId].push(review(reviewer, propertyId, uint8(rating), comment, 0));
        
        //FIXED: Now pushing propertyId to the array of reviewed properties for this user
        userReviewedProperties[reviewer].push(propertyId);
        
        //FIXED: Accessing product struct correctly
        products[propertyId].totalRating += rating;
        products[propertyId].numberOfReviews += 1; 
        reviewsCounter += 1;
        emit reviewAdded(propertyId, reviewer, uint8(rating), comment);
    }

    function getProductReviews(uint256 propertyId) external view returns(review[] memory){
        return reviews[propertyId];
    }

    //FIXED: Complete rewrite of getUserReviews function to work with the corrected mapping
    function getUserReviews(address user) external view returns (review[] memory){
        //Get all properties the user has reviewed
        uint256[] memory reviewedProperties = userReviewedProperties[user];
        uint256 totalReviews = 0;
        
        //First, count total reviews by this user across all properties
        for(uint256 i = 0; i < reviewedProperties.length; i++){
            uint256 propertyId = reviewedProperties[i];
            review[] memory propertyReviews = reviews[propertyId];
            
            for(uint256 j = 0; j < propertyReviews.length; j++){
                if(propertyReviews[j].reviewer == user){
                    totalReviews++;
                }
            }
        }
        
        //Create array with exact size needed
        review[] memory userReviewsList = new review[](totalReviews);
        uint256 currentIndex = 0;
        
        //Populate the array with user's reviews
        for(uint256 i = 0; i < reviewedProperties.length; i++){
            uint256 propertyId = reviewedProperties[i];
            review[] memory propertyReviews = reviews[propertyId];
            
            for(uint256 j = 0; j < propertyReviews.length; j++){
                if(propertyReviews[j].reviewer == user){
                    userReviewsList[currentIndex] = propertyReviews[j];
                    currentIndex++;
                }
            }
        }
        
        return userReviewsList;
    }

    function likeReview(uint256 propertyId, uint256 reviewId, address liker) external{
        review storage rev = reviews[propertyId][reviewId];
        rev.likes += 1;
        emit reviewLiked(propertyId, reviewId, liker, rev.likes);
    }

    //FIXED: Changed loop to iterate through propertyIndex instead of reviewsCounter
    function highestRatedProperty() external view returns (uint256){
        uint256 highestRating = 0;
        uint256 highestRatedPropertyId = 0;
        
        //Loop through all properties, not reviews
        for(uint256 i = 0; i < propertyIndex; i++){
            if(products[i].numberOfReviews > 0){
                uint256 averageRating = products[i].totalRating / products[i].numberOfReviews;
                if(averageRating > highestRating){
                    highestRating = averageRating;
                    highestRatedPropertyId = i;
                }
            }
        }
        return highestRatedPropertyId;
    }
}