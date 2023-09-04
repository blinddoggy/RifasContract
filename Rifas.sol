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
    }

    RifaInfo public rifa;
    uint256 public nextTokenId = 1;

    constructor(
        address _usdtAddress,
        string memory nombre,
        string memory simbolo,
        uint256 precio,
        uint256 maxBoletas,
        uint256 gananciaEmpresa
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
            saldoFinal: 0
        });

        for (uint256 i = 1; i <= maxBoletas; i++) {
            tokenAvailable[i] = true;
        }
    }

    event comprarEvents(
        address indexed buyer,
        uint256 prizeWithPercentage,
        uint256 totalSupply
    );

    function crearBoleta(string memory uri, uint256 numTokens2Mint)
        external
        onlyOwner
    {
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
            rifa.tokensRestantes = rifa.tokensRestantes.sub(1);
        }
    }

    function comprarBoleta(uint256 tokenId) external {
        require(
            tokenAvailable[tokenId],
            "No existe o ya no esta disponible esa boleta"
        );

        uint256 amount = rifa.precio * 1e6;
        require(
            usdt.transferFrom(msg.sender, address(this), amount),
            "Transferencia de USDT fallida"
        );

        uint256 ganancia = amount.mul(rifa.gananciaEmpresa).div(100);
        rifa.saldoFinal = rifa.saldoFinal.add(amount).sub(ganancia);

        rifa.tokensComprados = rifa.tokensComprados.add(1);
        rifa.tokensRestantes = rifa.tokensRestantes.sub(1);

        _transfer(address(this), msg.sender, tokenId);
        tokenAvailable[tokenId] = false;

        emit comprarEvents(msg.sender, rifa.saldoFinal, rifa.tokensMinteados);
    }

    function bigDistribute2NFT(
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
}
