// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract RifaNFT is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    IERC20 public usdt;
    mapping(uint256 => bool) public tokenAvailable;
    mapping(uint256 => bool) public tokenVendido;
    uint256[] public tokensVendidosArray;
    mapping(address => uint256) public nonces;
    address public creadorDelContrato;
    bool public compraBoletaHabilitada = true;

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
    uint256 public nextTokenId = 0;

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
        creadorDelContrato = msg.sender; // Establece al creador del contrato
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
            saldoFinal: rifa.saldoFinal,
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

    function comprarBoleta(uint256 boletaId) external {
        require(
            compraBoletaHabilitada,
            "La compra de boletas esta deshabilitada"
        );

        // Agregados mensajes de error para los require
        require(
            boletaId <= rifa.maxBoletas,
            "El tokenId supera el maximo de boletas permitido"
        );
        require(
            tokenAvailable[boletaId],
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
        tokenVendido[boletaId] = true;
        tokensVendidosArray.push(boletaId);

        // Transferencia del NFT al comprador
        _transfer(address(this), msg.sender, boletaId);
        tokenAvailable[boletaId] = false; // Actualizar el estado del token a "no disponible"

        rifa.tokensComprados = rifa.tokensComprados.add(1); //variable tokens comprados

        emit comprarEvents(
            msg.sender,
            payable(msg.sender),
            (rifa.saldoFinal * (100 - rifa.gananciaEmpresa)) / 1e8
        );
    }

    function ganador(
        uint256 boletaId,
        address recipient2Address,
        uint256 porcentajeParaRecipient
    ) public onlyOwner {
        require(
            votoUsuario1 && votoUsuario2,
            "Ambos usuarios deben votar para ejecutar"
        );

        require(rifa.saldoFinal > 0, "Rifa balance is zero");

        uint256 transferAmountToRecipient = rifa
            .saldoFinal
            .mul(100 - porcentajeParaRecipient)
            .div(100);
        uint256 transferAmountToRecipient2 = rifa
            .saldoFinal
            .mul(porcentajeParaRecipient)
            .div(100);

        require(
            usdt.approve(address(this), 100000000000000000),
            "Failed to approve"
        );

        address nftOwner = ownerOf(boletaId);

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
                recipient2Address,
                transferAmountToRecipient2
            ),
            "Failed to transfer to second recipient"
        );

        emit TransaccionEjecutada(msg.sender);
    }

    function getBoletasVendidas() public view returns (uint256[] memory) {
        return tokensVendidosArray;
    }

    function getRifa()
        public
        view
        returns (
            string memory nombre,
            string memory simbolo,
            uint256 precio,
            uint256 maxBoletas,
            uint256 tokensMinteados,
            uint256 tokensComprados,
            uint256 tokensRestantes,
            uint256 gananciaEmpresa,
            bool jugada,
            uint256 saldoFinal,
            uint256 fechaDeJuego,
            string memory descripcion
        )
    {
        return (
            rifa.nombre,
            rifa.simbolo,
            rifa.precio,
            rifa.maxBoletas,
            rifa.tokensMinteados,
            rifa.tokensComprados,
            rifa.tokensRestantes,
            rifa.gananciaEmpresa,
            rifa.jugada,
            (rifa.saldoFinal * (100 - rifa.gananciaEmpresa)) / 1e8,
            rifa.fechaDeJuego,
            rifa.descripcion
        );
    }

    function getUserAllowance() external view returns (uint256) {
        return usdt.allowance(msg.sender, address(this));
    }

    event comprarEvents(
        address userAddress,
        address payable relayerAddress,
        uint256 saldo
    );


    //sistema de doble confirmacion para reparticion del premio

    // Declaración de eventos para el sistema de votación
    event Voto(address indexed votante);
    event TransaccionEjecutada(address indexed ejecutor);

    // Variables para el sistema de votación
    address public usuario1;
    address public usuario2;
    bool public votoUsuario1;
    bool public votoUsuario2;
    uint256 public porcentajeParaRecipient2;
    uint256 public boletaIdParaPremio;
    address public recipient2ParaPremio;

    function autorizarUsuario(address usuario) external {
        require(usuario != address(0), "La direccion de usuario no es valida");

        if (usuario1 == address(0)) {
            usuario1 = usuario;
        } else if (usuario2 == address(0)) {
            usuario2 = usuario;
        } else {
            revert("Ya se han registrado dos usuarios para autorizacion");
        }
    }

    function votar(
        uint256 porcentaje,
        uint256 boletaId,
        address recipient2Address
    ) external {
        require(
            msg.sender == usuario1 || msg.sender == usuario2,
            "No estas autorizado para votar"
        );

        if (msg.sender == usuario1) {
            require(!votoUsuario1, "Ya has votado");
            votoUsuario1 = true;
            emit Voto(msg.sender);
        } else if (msg.sender == usuario2) {
            require(!votoUsuario2, "Ya has votado");
            votoUsuario2 = true;
            emit Voto(msg.sender);
        }

        // Almacenar los parámetros para la ejecución posterior
        porcentajeParaRecipient2 = porcentaje;
        boletaIdParaPremio = boletaId;
        recipient2ParaPremio = recipient2Address;

        // Verificar si ambos usuarios han votado y ejecutar la transacción si es así
        if (votoUsuario1 && votoUsuario2) {
            ganador(boletaIdParaPremio,recipient2ParaPremio,porcentajeParaRecipient2);
        }
    }

    function transferirNFT(uint256 tokenId, address destinatario) external {
        require(
            msg.sender == creadorDelContrato,
            "Solo el creador del contrato puede transferir NFTs"
        );
        require(
            ownerOf(tokenId) == address(this),
            "El NFT no pertenece al contrato de rifas"
        );

        _transfer(address(this), destinatario, tokenId);
        tokenAvailable[tokenId] = false; // Marca la boleta como "no disponible"
    }

    function deshabilitarCompraBoleta(bool deshabilitar) external onlyOwner {
        require(deshabilitar == true, "El numero proporcionado no es 00");
        compraBoletaHabilitada = false;
    }

    function enviarSaldoAcumulado(address destinatario) external onlyOwner {
        uint256 saldoDisponible = usdt.balanceOf(address(this));
        require(saldoDisponible > 0, "No hay saldo disponible para enviar");

        bool transferSuccess = usdt.transfer(destinatario, saldoDisponible);
        require(transferSuccess, "La transferencia de USDT fallo");

        // Actualizar el saldo final a cero después de la distribución
        rifa.saldoFinal = 0;
    }

    
}