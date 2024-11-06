//+------------------------------------------------------------------+
//|                                                    DataRetriever |
//|                                                      Amicobot.it |
//|                                             https://amicobot.it  |
//+------------------------------------------------------------------+
#property copyright "Eduardo Meli"
#property link      "https://amicobot.it"
#property version   "1.02"
#property strict
#define OP_BALANCE 6
#define OP_CREDIT 7
// Global variables
string sessionID;            // Session ID for the EA instance
input string apiKey = ""; // Your API Key
const string dataUrl = "https://amicobot.it/receive-data"; // Your WordPress endpoint
const string dailyUrl = "https://amicobot.it/receive-daily"; // Your WordPress endpoint
input string name = ""; // Name of your account



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime GetFirstTradeTime()
  {
   int totalHistory = OrdersHistoryTotal();
   datetime firstTime = TimeCurrent();

   for(int i = 0; i < totalHistory; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         datetime openTime = OrderOpenTime();
         if(openTime < firstTime)
            firstTime = openTime;
        }
     }
   return firstTime;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetFirstTradeTicket()
  {
   int totalHistory = OrdersHistoryTotal();
   datetime firstTime = TimeCurrent();
   int ticket = 0;
   for(int i = 0; i < totalHistory; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         datetime openTime = OrderOpenTime();
         if(openTime < firstTime)
           {
            firstTime = openTime;
            ticket = OrderTicket();
           }
        }
     }
   return ticket;
  }

//+------------------------------------------------------------------+
//| Function to get the initial balance when the EA started          |
//+------------------------------------------------------------------+
double GetInitialBalance()
  {
   double initialBalance = GetBalanceAtTrade(firstTradeTicket);
   return initialBalance;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime firstTradeTime = GetFirstTradeTime();
int firstTradeTicket = GetFirstTradeTicket();
double initialEquity = GetInitialBalance();
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   EventSetTimer(10);
   Print("Succesfully started");
   SendAccountData();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
   CollectAndSendHistoricalData();
   Sleep(2000);
   SendAccountData();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double realizedPL()
  {
   double totalProfit = 0.0;
   int totalOrders = OrdersHistoryTotal();


   for(int i = 0; i < totalOrders; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderCloseTime() > 0 && OrderType() < 3)
            totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
        }
     }
   return totalProfit;
  }

//+------------------------------------------------------------------+
//| Function to send account data                                    |
//+------------------------------------------------------------------+
void SendAccountData()
  {
   if(name == "")
     {
      Alert("No name has been specified. Aborting");
      ExpertRemove();
     }
// Collect account data
   long account_id = AccountInfoInteger(ACCOUNT_LOGIN);
   double profit = realizedPL();

// Calculate daily and monthly profit
   double dailyProfit = CalculateProfitForPeriod(PERIOD_D1);
   double monthlyProfit = CalculateProfitForPeriod(PERIOD_MN1);
   ulong running_days = GetRunningDays();
   double gain = CalculateGain();
   double win_rate = CalculateWinRate();

// Prepare data to send
   string postData = "name=" + name +
                     "&api_key=" + apiKey +
                     "&account_id=" +IntegerToString(account_id)+
                     "&profit=" +DoubleToString(profit, 2)+
                     "&daily=" +DoubleToString(dailyProfit, 2)+
                     "&monthly=" +DoubleToString(monthlyProfit, 2)+
                     "&running_days=" +IntegerToString(running_days)+
                     "&gain=" +DoubleToString(gain, 2)+
                     "&win_rate=" +DoubleToString(win_rate, 2) ;

   const string headers = "Content-Type: application/x-www-form-urlencoded\r\n";

   ResetLastError();

// Send WebRequest
   char resultData[];
   string resultHeaders;
   char postDataArr[];
   StringToCharArray(postData, postDataArr);

   int res = WebRequest("POST", dataUrl, headers, 0, postDataArr, resultData, resultHeaders);

   if(res == -1)
     {
      int error = GetLastError();
      Print("WebRequest failed. Error code: ", error);
      if(error == 4060)
        {
         Print("Possible cause: URL not listed in allowed URLs.");
         Print("Please add it in Tools > Options > Expert Advisors.");
        }
      if(error == 5203)
        {
         Print("WebRequest failure. Check for firewall settings or compatibility issues with your system.");
        }
      ExpertRemove();
     }
   else
     {
      Print("Account data sent successfully. Server response: ", CharArrayToString(resultData));
     }
  }

//+------------------------------------------------------------------+
//| Function to calculate profit for a specific period               |
//+------------------------------------------------------------------+
double CalculateProfitForPeriod(int period)
  {
   datetime fromTime = iTime(Symbol(), period, 0);
   datetime toTime = TimeCurrent();
   double profit = 0.0;

   int totalHistory = OrdersHistoryTotal();

   for(int i = totalHistory - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderCloseTime() >= fromTime && OrderCloseTime() <= toTime)
           {
            profit += OrderProfit() + OrderSwap() + OrderCommission();
           }
        }
     }
   return(profit);
  }

//+------------------------------------------------------------------+
//| Function to calculate the number of running days                 |
//+------------------------------------------------------------------+
ulong GetRunningDays()
  {
   return (ulong)(TimeCurrent()-firstTradeTime)/(PERIOD_D1*60);
  }



//+------------------------------------------------------------------+
//| Function to calculate gain percentage since the EA started       |
//+------------------------------------------------------------------+
double CalculateGain()
  {
   double initialBalance = GetInitialBalance();
   if(initialBalance == 0)
      return(0.0);
   double gain = (AccountInfoDouble(ACCOUNT_BALANCE) - initialBalance) / initialBalance * 100.0;
   return(gain);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetBalanceAtTrade(int tradeTicket)
  {
   double balance = 0.0;
   int totalOrders = OrdersHistoryTotal();

// Loop through historical orders from the oldest to the newest
   for(int i = totalOrders - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         int type = OrderType();
         if(type > 0)
           {
            balance += OrderProfit() + OrderSwap() - OrderCommission();
           }

         // Check if this is the specific trade
         if(OrderTicket() == tradeTicket)
           {
            // We've reached the trade; return the balance
            return balance;
           }
        }
      else
        {
         Print("Failed to select order at position ", i);
        }
     }

// If the trade was not found
   Print("Trade with ticket ", tradeTicket, " not found.");
   return -1; // Indicate error
  }




//+------------------------------------------------------------------+
//| Function to calculate the win rate percentage                    |
//+------------------------------------------------------------------+
double CalculateWinRate()
  {
   int totalTrades = 0;
   int winningTrades = 0;

   int totalHistory = OrdersHistoryTotal();

   for(int i = totalHistory - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderType() == OP_SELL || OrderType() == OP_BUY) // Only count buy/sell orders
           {
            totalTrades++;
            if(OrderProfit() + OrderCommission() + OrderSwap() > 0)
               winningTrades++;
           }
        }
     }
   if(totalTrades == 0)
      return(0.0);
   return(((double)winningTrades / totalTrades) * 100.0);
  }

//+------------------------------------------------------------------+
//| Function to URL-encode a string                                  |
//+------------------------------------------------------------------+
string urlencode(string s)
  {
   int len = StringLen(s);
   string encoded;
   uchar chars[];
   StringToCharArray(s,chars);
   for(int i = 0; i<len ; i++)
     {
      if(('a' <= chars[i] && chars[i] <= 'z') || ('A' <= chars[i] && chars[i] <= 'Z') || ('0' <= chars[i] && chars[i] <= '9'))
        {
         encoded = encoded + CharToStr(chars[i]);
        }
      else
        {
         encoded = encoded + StringFormat("%%%02X", chars[i]);
        }
     }
   return encoded;
  }




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CollectAndSendHistoricalData()
  {
// Determine the number of days since the first trade
   datetime current;
   int totalHistoryOrders = OrdersHistoryTotal();
   double profitDay = 0.0;
   double pipsDay = 0.0;
   double lotsDay = 0.0;
   double floatingPL = 0.0;
   double floatingPips = 0.0;
   double growthEquity = 0.0;
// Build JSON data
   string jsonData = "[";

   double profit = 0.0;
   for(int i = 0; i < totalHistoryOrders; i++)
     {

      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {profit = OrderProfit() + OrderSwap() + OrderCommission();}
      else
         Print(IntegerToString(GetLastError()));
      current = OrderOpenTime();
      if(OrderComment() == "Deposit")
         continue;
      // Date in "MM/DD/YYYY" format
      string dateStr = TimeToString(current, TIME_DATE);
      string dateFormatted = StringSubstr(dateStr, 5, 2) + "/" + StringSubstr(dateStr, 8, 2) + "/" + StringSubstr(dateStr, 0, 4);

      // Balance at the end of the day
      double balance = GetBalanceAtDate(current);

      if(OrderType() == OP_BUY || OrderType() == OP_SELL || OrderType() == OP_BALANCE || OrderType() == OP_CREDIT)
        {
         // Sum up profit
         profitDay = OrderProfit() + OrderSwap() + OrderCommission();
         // Sum up lots
         lotsDay += OrderLots();

         // Calculate pips
         double pips = CalculateOrderPips(OrderTicket());
         pipsDay += pips;
        }

      // Since we cannot get historical floating P/L and pips, we'll set them to zero
      floatingPL = 0.0;
      floatingPips = 0.0;

      // Calculate growthEquity
      double equity = balance; // Approximate equity as balance due to limitations
      if(initialEquity != 0)
         growthEquity = ((equity - initialEquity) / initialEquity) * 100.0;

      // Build JSON object for the day
      string jsonObject = "{";
      jsonObject += "\"date\": \"" + dateFormatted + "\",";
      jsonObject += "\"balance\": \"" + DoubleToString(balance, 2) + "\",";
      jsonObject += "\"pips\": \"" + DoubleToString(pipsDay, 2) + "\",";
      jsonObject += "\"lots\": \"" + DoubleToString(lotsDay, 2) + "\",";
      jsonObject += "\"floatingPL\": \"" + DoubleToString(floatingPL, 2) + "\",";
      jsonObject += "\"profit\": \"" + DoubleToString(profit, 4) + "\",";
      jsonObject += "\"growthEquity\": \"" + DoubleToString(growthEquity, 2) + "\",";
      jsonObject += "\"floatingPips\": \"" + DoubleToString(floatingPips, 2)+"\"";
      jsonObject += "}";

      // Append to jsonData
      jsonData += jsonObject;

      // Add comma if not last element
      if(i < totalHistoryOrders -1)
         jsonData += ",";
     }

   jsonData += "]";

// Send data via WebRequest
   SendData(jsonData);
  }


//+------------------------------------------------------------------+
//| Function to get balance at a specific date                       |
//+------------------------------------------------------------------+
double GetBalanceAtDate(datetime date)
  {
   double balance = AccountBalance();
   int totalHistory = OrdersHistoryTotal();

   for(int i = totalHistory - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         datetime closeTime = OrderCloseTime();
         if(closeTime > date)
           {
            int orderType = OrderType();
            double amount = OrderProfit() + OrderSwap() + OrderCommission();

            if(orderType == OP_BUY || orderType == OP_SELL)
              {
               // Subtract profit/loss from trades closed after the date
               balance -= amount;
              }
           }
        }
     }

   return balance;
  }

//+------------------------------------------------------------------+
//| Function to calculate pips for a closed order                    |
//+------------------------------------------------------------------+
double CalculateOrderPips(int ticket)
  {
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
      return 0.0;

   int orderType = OrderType();
   string symbol = OrderSymbol();
   double pointSize = MarketInfo(symbol, MODE_POINT);
   if(pointSize == 0)
      return 0;
   double digits = MarketInfo(symbol, MODE_DIGITS);
   if(digits == 3 || digits == 5)
      pointSize *= 10;
   if(orderType == OP_BUY)
     {
      return (OrderClosePrice() - OrderOpenPrice()) / pointSize;
     }
   else
      if(orderType == OP_SELL)
        {
         return (OrderOpenPrice() - OrderClosePrice()) / pointSize;
        }
   return 0.0;
  }

//+------------------------------------------------------------------+
//| Function to send data via WebRequest                             |
//+------------------------------------------------------------------+
void SendData(string jsonData)
  {
// Prepare headers
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
//Print("outgoing data: "+jsonData);
// Convert jsonData to uchar array

   long account_id = AccountInfoInteger(ACCOUNT_LOGIN);
   string postData = "account_id=" + IntegerToString(account_id)+
                     "&api_key=" + apiKey +
                     "&performance=" + jsonData;
   uchar postDataArr[];
   StringToCharArray(postData, postDataArr);
   ResetLastError();
//Print("array data "+CharArrayToString(postDataArr));
// Send WebRequest
   uchar result[];
   string resultHeaders;


   int res = WebRequest("POST", dailyUrl, headers, 5000, postDataArr, result, resultHeaders);
   if(res == -1)
     {
      int error = GetLastError();
      PrintFormat("WebRequest failed. Error code: %d - %s", error, ErrorDescription(error));
     }
   else
     {
      Print("Daily data sent successfully. Server response: ", CharArrayToString(result));
     }
  }

//+------------------------------------------------------------------+
//| Function to get error descriptions                               |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
  {
   switch(errorCode)
     {
      case 5200:
         return "No error";
      case 5201:
         return "No memory for request string";
      case 5202:
         return "Invalid URL";
      case 5203:
         return "HTTP request failed";
      case 5204:
         return "Request timeout";
      case 5205:
         return "Internal error";
      case 5206:
         return "Too many requests";
      default:
         return "Unknown error";
     }
  }
//+------------------------------------------------------------------+
