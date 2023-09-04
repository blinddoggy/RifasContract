// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RifaNFT is ERC721URIStorage, Ownable {
    using SafeMath for uint256;

    IERC20 public usdt;
    mapping(uint256 => bool) public tokenAvailable;
    mapping(uint256 => bool) public tokenVendido;
    uint256[] public tokensVendidosArray;

    struct RifaInfo {
        string nombre;
        string simbolo;
        uint256 precio;
        uint256 maxBoletas;
        uint256 tokensMinteados;
        uint256 tokensComprados;
        uint256 tokensRestantes;
        uint256 gananciaEmpresa;
        bool jugada;
        uint256 saldoFinal;
        uint256 fechaDeJuego;
        string descripcion;
    }

    RifaInfo public rifa;
    uint256 public nextTokenId = 1;

    constructor(
        address _usdtAddress,
        string memory nombre,
        string memory simbolo,
        uint256 precio,
        uint256 maxBoletas,
        uint256 gananciaEmpresa,
        uint256 fechaDeJuego,
        string memory descripcion
    ) ERC721(nombre, simbolo) {
        usdt = IERC20(_usdtAddress);
        rifa = RifaInfo({
            nombre: nombre,
            simbolo: simbolo,
            precio: precio,
            maxBoletas: maxBoletas,
            tokensMinteados: 0,
            tokensComprados: 0,
            tokensRestantes: maxBoletas,
            gananciaEmpresa: gananciaEmpresa,
            jugada: false,
            saldoFinal: rifa.saldoFinal.mul(100 - gananciaEmpresa).div(1e8),
            fechaDeJuego: fechaDeJuego,
            descripcion: descripcion
        });

        for (uint256 i = 1; i <= maxBoletas; i++) {
            tokenAvailable[i] = true;
        }
    }

    function setJugada(bool estado) external onlyOwner {
        rifa.jugada = estado;
    }

    function crearBoleta(string memory uri, uint256 numTokens2Mint)
        external
        onlyOwner
    {
        // Agregado un mensaje de error para el require
        require(
            rifa.tokensMinteados.add(numTokens2Mint) <= rifa.maxBoletas,
            "Se superaria el maximo de boletas"
        );

        for (uint256 i = 0; i < numTokens2Mint; i++) {
            _mint(address(this), nextTokenId);
            _setTokenURI(nextTokenId, uri);
            tokenAvailable[nextTokenId] = true;
            nextTokenId = nextTokenId.add(1);
            rifa.tokensMinteados = rifa.tokensMinteados.add(1);
            rifa.tokensRestantes = rifa.tokensRestantes.sub(1); // Actualizado el número de tokens restantes
        }
    }

    function comprarBoleta(uint256 tokenId) external {
        // Agregados mensajes de error para los require
        require(
            tokenId <= rifa.maxBoletas,
            "El tokenId supera el maximo de boletas permitido"
        );
        require(tokenId > 0, "El tokenId debe ser mayor que cero");
        require(
            tokenAvailable[tokenId],
            "No existe o ya no esta disponible esa boleta"
        );

        uint256 amount = rifa.precio * 1e6; // Precio multiplicado para tener 6 decimales
        require(
            usdt.balanceOf(msg.sender) >= amount,
            "No tienes suficientes USDT"
        );

        // Verificar si el usuario ha aprobado la transferencia
        require(
            usdt.allowance(msg.sender, address(this)) >= amount,
            "Aprobacion de USDT insuficiente"
        );

        bool transferSuccess = usdt.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(transferSuccess, "Transferencia de USDT fallida");
        //actualiza saldo final
        rifa.saldoFinal = rifa.saldoFinal.add(amount);
        //mapping de tokens vendidos
        tokenVendido[tokenId] = true;
        tokensVendidosArray.push(tokenId);

        // Transferencia del NFT al comprador
        _transfer(address(this), msg.sender, tokenId);
        tokenAvailable[tokenId] = false; // Actualizar el estado del token a "no disponible"

        rifa.tokensComprados = rifa.tokensComprados + 1; //variable tokens comprados

        emit comprarEvents(msg.sender, rifa.saldoFinal, rifa.tokensMinteados);
    }

    function ganador(
        uint256 tokenId,
        address recipient2,
        uint256 percentageToRecipient2
    ) public onlyOwner {
        require(rifa.saldoFinal > 0, "Rifa balance is zero");

        uint256 transferAmountToRecipient = rifa
            .saldoFinal
            .mul(100 - percentageToRecipient2)
            .div(100);
        uint256 transferAmountToRecipient2 = rifa
            .saldoFinal
            .mul(percentageToRecipient2)
            .div(100);

        require(
            usdt.approve(address(this), 100000000000000000),
            "Failed to approve"
        );

        address nftOwner = ownerOf(tokenId);

        require(
            usdt.transferFrom(
                address(this),
                nftOwner,
                transferAmountToRecipient
            ),
            "Failed to transfer to NFT owner"
        );
        require(
            usdt.transferFrom(
                address(this),
                recipient2,
                transferAmountToRecipient2
            ),
            "Failed to transfer to second recipient"
        );
    }

    function getTokensVendidos() public view returns (uint256[] memory) {
        return tokensVendidosArray;
    }

    event comprarEvents(
        address indexed buyer,
        uint256 prizeWithPercentage,
        uint256 totalSupply
    );
}
