
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Rifas is ERC721, Ownable {
    uint256 public currentTokenId = 0;
    
    IERC20 public usdtToken;
    uint256 public nftPrice;

    constructor(string memory name, string memory symbol, IERC20 _usdtToken, uint256 _nftPrice) ERC721(name, symbol) {
        usdtToken = _usdtToken;
        nftPrice = _nftPrice;
    }
    
    function mint(address to, uint256 numTokens) public  {
        uint256 newTokenId = currentTokenId;
        for(uint256 i = 0; i < numTokens; i++) {
            _mint(to, newTokenId + i);
        }
        currentTokenId += numTokens;
    }

    function approveTo(address operator, uint256 tokenId) public onlyOwner {
            _approve(operator, tokenId);
        }

    function approveContract(address spender, uint256 amount) external {
        usdtToken.approve(spender, amount);
    }

    function approveFactory(address spender, uint256 amount) external onlyOwner {
        usdtToken.approve(spender, amount);
    }


    }

contract ProjectRifasFactory is Ownable {

    IERC20 public usdtToken;

    constructor(IERC20 _usdtToken) {
        usdtToken = _usdtToken;
    }

   struct Project {
        Rifas rifa;
        string name;
        string symbol;
        uint256 mintedTokens;
        uint256 currentTokenId;
        uint256 date;
        uint256 profitPercentage;  
        uint256 usdtBalance;  
    }



    Project[] public projects;


    function getProjects() public view returns (Project[] memory) {
        Project[] memory updatedProjects = new Project[](projects.length);
            for (uint256 i = 0; i < projects.length; i++) {
                updatedProjects[i] = projects[i];
                updatedProjects[i].usdtBalance = usdtToken.balanceOf(address(projects[i].rifa));
            }
        return updatedProjects;
    }


   
  function createProject(string memory name, string memory symbol, uint256 numTokens, uint256 _nftPrice, uint256 date, uint256 _profitPercentage) public onlyOwner returns (Project memory) {
        require(_profitPercentage <= 100, "Percentage cannot be greater than 100");
        Rifas newRifa = new Rifas(name, symbol, usdtToken, _nftPrice);
        newRifa.mint(address(newRifa), numTokens);
        
        Project memory newProject = Project({
            rifa: newRifa,
            name: name,
            symbol: symbol,
            mintedTokens: numTokens,
            currentTokenId: 0,
            date: date,
            profitPercentage: _profitPercentage,  // Estableciendo el porcentaje de ganancia
            usdtBalance: 0  // Agrega un valor inicial para usdtBalance
        });     
        projects.push(newProject);
        return newProject;
    }

   function buyAndMint(uint256 projectId, uint256 numTokens) external {
    Project storage project = projects[projectId];
    uint256 totalCost = numTokens * project.rifa.nftPrice();

    // Realizar la aprobación del contrato ProjectRifasFactory para transferir USDT
    usdtToken.approve(address(this), totalCost);

    // Transfiere USDT del remitente al contrato de rifa
    usdtToken.transferFrom(msg.sender, address(project.rifa), totalCost);

    // Acuña los tokens NFT
    project.rifa.mint(msg.sender, numTokens);
}



    function ganador(uint256 projectId, uint256 tokenId) public onlyOwner {
        // Asegúrate de que el projectId es válido
        require(projectId < projects.length, "Invalid projectId");

        // Obtiene la dirección del propietario del NFT con el ID proporcionado
        address nftOwner = projects[projectId].rifa.ownerOf(tokenId);

        // Determina cuánto USDT tiene la rifa en su balance
        uint256 contractBalance = usdtToken.balanceOf(address(projects[projectId].rifa));
        
        // Asegúrate de que el contrato tiene un balance positivo de USDT
        require(contractBalance > 0, "Insufficient contract balance");

        // Transfiere todo el USDT de la rifa al propietario del NFT
        usdtToken.transfer(nftOwner, contractBalance);
    }


    function transferToken(uint256 projectId, address to, uint256 tokenId) public  {
        Project storage project = projects[projectId];
        require(tokenId < project.mintedTokens, "Invalid tokenId");
        
        project.rifa.safeTransferFrom(address(project.rifa), to, tokenId);
        project.currentTokenId++;
    }

    function ownerOfToken(uint256 projectId, uint256 tokenId) public view returns (address) {
        Project storage project = projects[projectId];
        return project.rifa.ownerOf(tokenId);
    }

    function getBalanceOfUSDT(uint256 projectId) public view returns (uint256) {
        Project storage project = projects[projectId];
        return usdtToken.balanceOf(address(project.rifa));
    }



    // Función para verificar el balance de USDT de una rifa en particular.
    function checkRifaBalance(uint256 projectId) public view returns (uint256) {
        require(projectId < projects.length, "Invalid projectId");
        return usdtToken.balanceOf(address(projects[projectId].rifa));
    }

   function testTransfer(uint256 projectId) public onlyOwner {
        require(projectId < projects.length, "Invalid projectId");
        
        uint256 testAmount = 1e6; // Asumiendo que USDT tiene 6 decimales, esto es 1 USDT.
        
        Project storage project = projects[projectId];
        project.rifa.approveFactory(address(this), testAmount);
        
        uint256 rifaBalance = usdtToken.balanceOf(address(project.rifa));
        
        require(rifaBalance >= testAmount, "Rifa balance is less than test amount");

        // Transferir la cantidad de prueba al propietario de ProjectRifasFactory.
        usdtToken.transferFrom(address(project.rifa), owner(), testAmount);
    }


    function winner2Address(uint256 projectId, address recipient) public onlyOwner {
        require(projectId < projects.length, "Invalid projectId");
        
        uint256 transferAmount = 1e6; // Asumiendo que USDT tiene 6 decimales, esto es 1 USDT.
        
        Project storage project = projects[projectId];
        project.rifa.approveFactory(address(this), transferAmount);
        
        uint256 rifaBalance = usdtToken.balanceOf(address(project.rifa));
        
        require(rifaBalance >= transferAmount, "Rifa balance is less than transfer amount");

        // Transferir la cantidad al destinatario especificado.
        usdtToken.transferFrom(address(project.rifa), recipient, transferAmount);
    }


    function transferFullBalance(uint256 projectId, address recipient) public onlyOwner {
        require(projectId < projects.length, "Invalid projectId");
        
        Project storage project = projects[projectId];
        uint256 rifaBalance = usdtToken.balanceOf(address(project.rifa));
        
        require(rifaBalance > 0, "Rifa balance is zero");

        // Aprobar la transferencia de todo el saldo del contrato.
        project.rifa.approveFactory(address(this), rifaBalance);

        // Transferir el saldo completo al destinatario especificado.
        usdtToken.transferFrom(address(project.rifa), recipient, rifaBalance);
    }


   function calculateDistributeAmounts(uint256 projectId, uint256 percentageToRecipient2) public view returns (uint256 transferAmountToRecipient, uint256 transferAmountToRecipient2) {
    require(projectId < projects.length, "Invalid projectId");
    require(percentageToRecipient2 <= 100, "Percentage cannot be greater than 100");
    
    Project storage project = projects[projectId];
    uint256 rifaBalance = usdtToken.balanceOf(address(project.rifa));
    
    require(rifaBalance > 0, "Rifa balance is zero");

    uint256 totalTransferAmount = rifaBalance;

    // Calcular los montos a transferir a cada destinatario según los porcentajes.
    transferAmountToRecipient2 = (totalTransferAmount * percentageToRecipient2) / 100;
    transferAmountToRecipient = totalTransferAmount - transferAmountToRecipient2;
}


function bigDistribute(uint256 projectId, address recipient, address recipient2, uint256 percentageToRecipient2) public onlyOwner {
    require(projectId < projects.length, "Invalid projectId");

    // Obtener los montos a transferir a cada destinatario
    (uint256 transferAmountToRecipient, uint256 transferAmountToRecipient2) = calculateDistributeAmounts(projectId, percentageToRecipient2);

    Project storage project = projects[projectId];
    uint256 rifaBalance = usdtToken.balanceOf(address(project.rifa));
    
    require(rifaBalance > 0, "Rifa balance is zero");

    // Aprobar la transferencia de todo el saldo del contrato.
    project.rifa.approveFactory(address(this), rifaBalance);

    // Transferir el monto al primer destinatario
    usdtToken.transferFrom(address(project.rifa), recipient, transferAmountToRecipient);

    // Transferir el monto al segundo destinatario
    usdtToken.transferFrom(address(project.rifa), recipient2, transferAmountToRecipient2);
}


function bigDistribute2NFT(uint256 projectId, uint256 tokenId, address recipient2, uint256 percentageToRecipient2) public onlyOwner {
    require(projectId < projects.length, "Invalid projectId");

    // Obtener los montos a transferir a cada destinatario
    (uint256 transferAmountToRecipient, uint256 transferAmountToRecipient2) = calculateDistributeAmounts(projectId, percentageToRecipient2);

    Project storage project = projects[projectId];
    uint256 rifaBalance = usdtToken.balanceOf(address(project.rifa));
    
    require(rifaBalance > 0, "Rifa balance is zero");

    // Aprobar la transferencia de todo el saldo del contrato.
    project.rifa.approveFactory(address(this), rifaBalance);

    // Obtener la dirección del propietario del NFT
    address nftOwner = project.rifa.ownerOf(tokenId);

    // Transferir el monto al primer destinatario
    usdtToken.transferFrom(address(project.rifa), nftOwner, transferAmountToRecipient);

    // Transferir el monto al segundo destinatario
    usdtToken.transferFrom(address(project.rifa), recipient2, transferAmountToRecipient2);
}



function approveFactorySpender(uint256 amount) public onlyOwner {
    // Asumiendo que `usdtToken` es la instancia del token USDT
    usdtToken.approve(address(this), amount);
}

    
}
