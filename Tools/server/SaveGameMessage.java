package net.sf.freecol.common.networking;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.xml.stream.XMLStreamException;
import net.sf.freecol.FreeCol;
import net.sf.freecol.common.io.FreeColXMLReader;
import net.sf.freecol.common.model.Game;
import net.sf.freecol.server.FreeColServer;
import net.sf.freecol.server.model.ServerPlayer;

/**
 * Optional NovaloriaClient extension: export a full server save to the game host.
 */
public final class SaveGameMessage extends AttributeMessage {
    public static final String TAG = "saveGame";
    private static final Logger logger = Logger.getLogger(SaveGameMessage.class.getName());
    private static final long MAX_BYTES = 8 * 1024 * 1024;

    public SaveGameMessage(Game game, FreeColXMLReader xr) throws XMLStreamException {
        super(TAG, xr, "encoding", "data");
    }

    private SaveGameMessage(String data) {
        super(TAG, "encoding", "base64", "data", data);
    }

    @Override
    public boolean currentPlayerMessage() {
        return true;
    }

    @Override
    public ChangeSet serverHandler(FreeColServer server, ServerPlayer player) {
        if (!player.isAdmin()) {
            return player.clientError("Only the game administrator may export a savegame.");
        }
        Path temporary = null;
        String originalName = FreeCol.getName();
        try {
            logger.info("Creating client savegame export");
            temporary = Files.createTempFile("freecol-client-save-", ".fsg");
            // FreeCol stores FreeCol.name as the savegame owner and later uses
            // it as the client login name when opening the save. The process
            // name (often the macOS account name) may not match the saved
            // player's name, so temporarily use the actual player name.
            FreeCol.setName(player.getName());
            server.saveGame(temporary.toFile(), null, null);
            if (Files.size(temporary) > MAX_BYTES) {
                return player.clientError("Savegame exceeds the 8 MiB export limit.");
            }
            String data = Base64.getEncoder().encodeToString(Files.readAllBytes(temporary));
            logger.info("Client savegame export ready: " + Files.size(temporary) + " bytes");
            return ChangeSet.simpleChange(player, new SaveGameMessage(data));
        } catch (IOException e) {
            logger.log(Level.WARNING, "Client savegame export failed", e);
            return player.clientError("Server could not create the savegame: " + e.getMessage());
        } finally {
            if (temporary != null) {
                try {
                    Files.deleteIfExists(temporary);
                } catch (IOException e) {
                    logger.log(Level.WARNING, "Could not remove temporary savegame", e);
                }
            }
            FreeCol.setName(originalName);
        }
    }
}
