// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { System } from "@latticexyz/world/src/System.sol";
import { MapItem,MapItemTableId,RaiseColddown,TransactionList,PlayerGameResult, TradeListData, TradeList, PassiveTransactionData, IsTrading, PassiveTransaction, UnsolicitedTransaction,IsTrading, AssetsListData,AssetsList,Player,Game ,GameData,GameState,PlayerData,PlayerTableId,IsPlayer} from "../codegen/Tables.sol";

import { addressToEntityKey } from "../addressToEntityKey.sol";
import { query, QueryFragment, QueryType } from "@latticexyz/world/src/modules/keysintable/query.sol";

contract GameFlowSystem is System {

        
    struct ScoreObj{
        bytes32 player;
        int32 totalScore;
        int8 gpu;
        int8 bitcoin;
        int8 battery;
        int8 leiter;
        int8 gold;
        int8 oil;
    }

  function finishGame() public{
        uint32 gameState = GameState.get();
        require(gameState == 2,"Game is finished already");

        GameState.set(1);
        bytes32 player = addressToEntityKey(_msgSender());

        QueryFragment[] memory fragments = new QueryFragment[](1);
        fragments[0] = QueryFragment(QueryType.Has, PlayerTableId, new bytes(0));
        bytes32[][] memory keyTuples = query(fragments);

        // uint256 length = keyTuples.length;
        // if(length != 0 && keyTuples[0].length > 0){
        //     length = length * keyTuples[0].length;
        // }
        uint256 length = 10;

        ScoreObj[] memory scoreObjList = new ScoreObj[](keyTuples.length);
        uint32 index = 0;

        for (uint256 a = 0; a < keyTuples.length; a++) {
            bytes32[] memory assetsLists = keyTuples[a];

            for (uint256 i = 0; i < assetsLists.length; i++) {
                bytes32 tmpPlayer = assetsLists[i];
                if(!isBytes32NonZero(tmpPlayer)) continue;

                AssetsListData memory alData = AssetsList.get(tmpPlayer);

                int8 score1 = calculateScore(alData.gpu);
                int8 score2 = calculateScore(alData.bitcoin);
                int8 score3 = calculateScore(alData.battery);
                int8 score4 = calculateScore(alData.leiter);
                int8 score5 = calculateScore(alData.gold);
                int8 score6 = calculateScore(alData.oil);
                int32 totalScore = score1 + score2 + score3 + score4 + score5 + score6; 
                ScoreObj memory newItem = ScoreObj(tmpPlayer,totalScore,alData.gpu,alData.bitcoin,alData.battery,alData.leiter,alData.gold,alData.oil);
                
                assert(index < scoreObjList.length);
                scoreObjList[index] = newItem;
                index = index + 1;
            }
        }

        scoreObjList = sortScores(scoreObjList);

        for (uint256 a = 0; a < scoreObjList.length; a++) {
            ScoreObj memory obj = scoreObjList[a];
            bytes32 p = obj.player;
            int32 rank = convertIntToUint(a);
            int32 totalScore = obj.totalScore;
            int8 gpu = obj.gpu;
            int8 bitcoin = obj.bitcoin;
            int8 battery = obj.battery;
            int8 leiter = obj.leiter;
            int8 gold = obj.gold;
            int8 oil = obj.oil;

            PlayerGameResult.set(p,rank,totalScore,gpu,bitcoin,battery,leiter,gold,oil);
        }

        clearPlayerComponents();
        clearMapComponents();
        resetGame();
    }

    function clearPlayerComponents() private {
        QueryFragment[] memory fragments = new QueryFragment[](1);
        fragments[0] = QueryFragment(QueryType.Has, PlayerTableId, new bytes(0));
        bytes32[][] memory keyTuples = query(fragments);

        
        for (uint256 a = 0; a < keyTuples.length; a++) {
            bytes32[] memory allPlayers = keyTuples[a];

            for (uint256 i = 0; i < allPlayers.length; i++) {
                bytes32 tmpPlayer = allPlayers[i];

                //Player
                IsPlayer.deleteRecord(tmpPlayer);
                Player.deleteRecord(tmpPlayer);

                //Trade
                AssetsList.deleteRecord(tmpPlayer);
                UnsolicitedTransaction.deleteRecord(tmpPlayer);
                PassiveTransaction.deleteRecord(tmpPlayer);
                TradeList.deleteRecord(tmpPlayer);
                TransactionList.deleteRecord(tmpPlayer);
                RaiseColddown.deleteRecord(tmpPlayer);

                //
            }
        }
    }

    function clearMapComponents() private{

        QueryFragment[] memory fragments = new QueryFragment[](1);
        fragments[0] = QueryFragment(QueryType.Has, MapItemTableId, new bytes(0));
        bytes32[][] memory keyTuples = query(fragments);

        
        for (uint256 a = 0; a < keyTuples.length; a++) {
            bytes32[] memory array1 = keyTuples[a];

            for (uint256 i = 0; i < array1.length; i++) {
                bytes32 tmpEntity = array1[i];

                MapItem.deleteRecord(tmpEntity);
            }
        }
    }

    function resetGame() private{
        uint gameSec = 48 * 3600;
        uint startWaitSec = 8;
        uint256 gameId = block.timestamp;
        uint256 startTime = block.timestamp + startWaitSec;
        uint256 endTime = startTime + gameSec;

        Game.set(gameId, startTime, endTime);
    }

    function isBytes32NonZero(bytes32 value) private pure returns (bool) {
        for (uint256 i = 0; i < 32; i++) {
            if (value[i] != 0x00) {
                return true;
            }
        }
        return false;
    }

    function convertIntToUint(uint256 number) private pure returns (int32) {
        require(number >= 0, "Negative number cannot be converted to uint256");
        return int32(uint32(number));
    }
    function calculateScore(int8 num) private pure returns (int8) {
        int8 score = 0;
        for (int8 i = 1; i <= num; i++) {
            score += i;
        }
        return score;
    }

    function sortScores(ScoreObj[] memory scores) private pure returns (ScoreObj[] memory) {
        uint256 length = scores.length;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (scores[j].totalScore < scores[j + 1].totalScore) {
                    ScoreObj memory temp = scores[j];
                    scores[j] = scores[j + 1];
                    scores[j + 1] = temp;
                }
            }
        }
        return scores;
    }


    
}
