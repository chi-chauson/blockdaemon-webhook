package ly.bit.blockdaemon.webhook.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import ly.bit.blockdaemon.webhook.model.WebhookEvent;
import ly.bit.blockdaemon.webhook.model.data.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class WebhookEventDispatcher {

    private static final Logger log = LoggerFactory.getLogger(WebhookEventDispatcher.class);

    private final ObjectMapper objectMapper;

    public WebhookEventDispatcher(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public void dispatch(WebhookEvent event) {
        log.debug("Dispatching event id={} type={} protocol={} network={}",
                event.id(), event.eventType(), event.protocol(), event.network());

        switch (event.eventType()) {
            case "unified_confirmed_tx"           -> handleConfirmedTx(event);
            case "unified_confirmed_tx_trace"     -> handleTxTrace(event);
            case "unified_confirmed_tx_log"       -> handleTxLog(event);
            case "unified_confirmed_balance"      -> handleConfirmedBalance(event);
            case "unified_staking_status"         -> handleStakingStatus(event);
            case "unified_staking_reward"         -> handleStakingReward(event);
            case "unified_pending_tx"             -> handlePendingTx(event);
            case "unified_pending_tx_removed"     -> handlePendingTxRemoved(event);
            case "unified_confirmed_input"         -> handleUtxo(event, "input");
            case "unified_confirmed_output"        -> handleUtxo(event, "output");
            case "unified_confirmed_token_balance" -> handleConfirmedTokenBalance(event);
            case "unified_trustline"               -> handleTrustline(event);
            case "unified_block"                   -> handleBlock(event);
            case "unified_reorg"                   -> handleReorg(event);
            default -> log.warn("Unhandled event type: {} — add a handler or check recorded NDJSON for schema",
                    event.eventType());
        }
    }

    private void handleConfirmedTx(WebhookEvent event) {
        parse(event, ConfirmedTxData.class).ifPresent(data -> {
            log.info("[confirmed_tx] txId={} status={} block={} transfers={}",
                    data.txId(), data.status(), data.blockNumber(),
                    data.transfers() != null ? data.transfers().size() : 0);
            if (data.transfers() != null) {
                data.transfers().forEach(t ->
                        log.info("  transfer asset={} from={} to={} value={}",
                                t.asset(), t.from(), t.to(), t.value()));
            }
        });
    }

    private void handleTxTrace(WebhookEvent event) {
        parse(event, TxTraceData.class).ifPresent(data ->
                log.info("[tx_trace] type={} from={} to={} txHash={} block={}",
                        data.type(), data.from(), data.to(), data.txHash(), data.blockNumber()));
    }

    private void handleTxLog(WebhookEvent event) {
        parse(event, TxLogData.class).ifPresent(data -> {
            log.info("[tx_log] txId={} status={} block={} transfers={}",
                    data.txId(), data.status(), data.blockNumber(),
                    data.transfers() != null ? data.transfers().size() : 0);
            if (data.transfers() != null) {
                data.transfers().forEach(t ->
                        log.info("  token transfer asset={} from={} to={} value={}",
                                t.asset(), t.from(), t.to(), t.value()));
            }
        });
    }

    private void handleConfirmedBalance(WebhookEvent event) {
        parse(event, ConfirmedBalanceData.class).ifPresent(data ->
                log.info("[confirmed_balance] address={} asset={} value={} block={}",
                        data.address(), data.asset(), data.value(), data.blockNumber()));
    }

    private void handleStakingStatus(WebhookEvent event) {
        parse(event, StakingStatusData.class).ifPresent(data ->
                log.info("[staking_status] validatorIndex={} pubkey={} status={} block={}",
                        data.validatorIndex(), data.validatorPubkey(), data.status(), data.blockNumber()));
    }

    private void handleStakingReward(WebhookEvent event) {
        parse(event, StakingRewardData.class).ifPresent(data ->
                log.info("[staking_reward] validatorIndex={} pubkey={} amount={} block={}",
                        data.validatorIndex(), data.validatorPubkey(), data.amount(), data.blockNumber()));
    }

    private void handlePendingTx(WebhookEvent event) {
        parse(event, PendingTxData.class).ifPresent(data ->
                log.info("[pending_tx] txHash={} from={} to={} value={}",
                        data.txHash(), data.from(), data.to(), data.value()));
    }

    private void handlePendingTxRemoved(WebhookEvent event) {
        parse(event, PendingTxData.class).ifPresent(data ->
                log.info("[pending_tx_removed] txHash={} from={} to={}",
                        data.txHash(), data.from(), data.to()));
    }

    private void handleUtxo(WebhookEvent event, String direction) {
        parse(event, UtxoData.class).ifPresent(data ->
                log.info("[utxo_{}] txHash={} address={} value={} block={}",
                        direction, data.txHash(), data.address(), data.value(), data.blockNumber()));
    }

    private void handleConfirmedTokenBalance(WebhookEvent event) {
        parse(event, ConfirmedTokenBalanceData.class).ifPresent(data ->
                log.info("[confirmed_token_balance] address={} token={} symbol={} balance={} slot={}",
                        data.address(), data.tokenAddress(), data.tokenSymbol(), data.balance(), data.slot()));
    }

    private void handleTrustline(WebhookEvent event) {
        parse(event, TrustlineData.class).ifPresent(data ->
                log.info("[trustline] account={} currency={} issuer={} limit={} balance={} txHash={}",
                        data.account(), data.currency(), data.issuer(), data.limit(), data.balance(), data.txHash()));
    }

    private void handleBlock(WebhookEvent event) {
        parse(event, BlockData.class).ifPresent(data ->
                log.info("[block] blockNumber={} blockHash={} parentHash={}",
                        data.blockNumber(), data.blockHash(), data.parentHash()));
    }

    private void handleReorg(WebhookEvent event) {
        parse(event, ReorgData.class).ifPresent(data ->
                log.info("[reorg] fromBlock={} toBlock={} added={} removed={}",
                        data.fromBlock(), data.toBlock(), data.addedBlocks(), data.removedBlocks()));
    }

    private <T> java.util.Optional<T> parse(WebhookEvent event, Class<T> type) {
        try {
            return java.util.Optional.of(objectMapper.treeToValue(event.data(), type));
        } catch (Exception e) {
            log.error("Failed to parse data for event type={} id={}: {}",
                    event.eventType(), event.id(), e.getMessage());
            return java.util.Optional.empty();
        }
    }
}
