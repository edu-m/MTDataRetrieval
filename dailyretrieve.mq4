//+------------------------------------------------------------------+
//|                                                    DataSenderEA.mq4 |
//|                         Your Name or Company                      |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.02"
#property strict

// Define OP_BALANCE for deposit/withdrawal operations
#define OP_BALANCE 6

// Global variables
string apiKey = "abc";       // Replace with your actual API key
string url = "https://test.local/receive-daily"; // Replace with your actual endpoint URL
double initialBalance;
double initialEquity;
datetime firstTradeTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Store initial balance and equity
   initialBalance = AccountBalance();
   initialEquity = AccountEquity();

// Get the time of the first trade
   firstTradeTime = GetFirstTradeTime();

   if(firstTradeTime == 0)
     {
      Print("No trade history found.");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Cleanup code if needed
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static bool dataSent = false;

// Send data once after initialization
   if(!dataSent)
     {
      CollectAndSendHistoricalData();
      dataSent = true;
     }
  }

//+------------------------------------------------------------------+
//| Function to collect and send historical data                     |
//+------------------------------------------------------------------+
void CollectAndSendHistoricalData()
  {
// Determine the number of days since the first trade
   datetime startDate = firstTradeTime;
   datetime endDate = TimeCurrent();
   int totalDays = (int)((endDate - startDate) / 86400) + 1;

// Build JSON data
   string jsonData = "[";

   for(int i = 0; i < totalDays; i++)
     {
      datetime dayStart = startDate + i * 86400;
      datetime dayEnd = dayStart + 86399;

      // Date in "MM/DD/YYYY" format
      string dateStr = TimeToString(dayStart, TIME_DATE);
      string dateFormatted = StringSubstr(dateStr, 5, 2) + "/" + StringSubstr(dateStr, 8, 2) + "/" + StringSubstr(dateStr, 0, 4);

      // Balance at the end of the day
      double balance = GetBalanceAtDate(dayEnd);

      // Initialize variables
      double profitDay = 0.0;
      double pipsDay = 0.0;
      double lotsDay = 0.0;
      double floatingPL = 0.0;
      double floatingPips = 0.0;
      double growthEquity = 0.0;

      // Calculate profit, pips, and lots for closed orders on that day
      int totalHistoryOrders = OrdersHistoryTotal();

      for(int j = totalHistoryOrders - 1; j >= 0; j--)
        {
         if(OrderSelect(j, SELECT_BY_POS, MODE_HISTORY))
           {
            if(OrderCloseTime() >= dayStart && OrderCloseTime() <= dayEnd)
              {
               int orderType = OrderType();
               if(orderType == OP_BUY || orderType == OP_SELL)
                 {
                  // Sum up profit
                  profitDay += OrderProfit() + OrderSwap() + OrderCommission();

                  // Sum up lots
                  lotsDay += OrderLots();

                  // Calculate pips
                  double pips = CalculateOrderPips(OrderTicket());
                  pipsDay += pips;
                 }
              }
           }
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
      jsonObject += "\"profit\": \"" + DoubleToString(profitDay, 4) + "\",";
      jsonObject += "\"growthEquity\": \"" + DoubleToString(growthEquity, 2) + "\",";
      jsonObject += "\"floatingPips\": \"" + DoubleToString(floatingPips, 2)+"\"";
      jsonObject += "}";

      // Append to jsonData
      jsonData += jsonObject;

      // Add comma if not last element
      if(i < totalDays -1 )
         jsonData += ",";
     }

   jsonData += "]";
   int file_handle=FileOpen(".//data.txt",FILE_WRITE|FILE_TXT);
   if(file_handle == INVALID_HANDLE)
      Print("invalid handle");
   else
      Print(FileWriteString(file_handle,jsonData));
// Send data via WebRequest
   Print(StringLen(jsonData));
   SendData(jsonData);
  }

//+------------------------------------------------------------------+
//| Function to get the time of the first trade                      |
//+------------------------------------------------------------------+
datetime GetFirstTradeTime()
  {
   int totalHistory = OrdersHistoryTotal();
   datetime firstTime = 0;

   for(int i = 0; i < totalHistory; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         datetime openTime = OrderOpenTime();
         if(firstTime == 0 || openTime < firstTime)
            firstTime = openTime;
        }
     }
   return firstTime;
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
            else
               if(orderType == OP_BALANCE)
                 {
                  // Subtract deposits/withdrawals made after the date
                  balance -= OrderProfit();
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
// Print(DoubleToStr(pointSize));
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
   string headers = "API-Key: " + apiKey + "\r\n" +
                    "Content-Type: application/x-www-form-urlencoded\r\n";
//Print("outgoing data: "+jsonData);
// Convert jsonData to uchar array

   long account_id = AccountInfoInteger(ACCOUNT_LOGIN);
   string postData = "account_id=" + IntegerToString(account_id)+
                     "&performance=" + jsonData;
   uchar postDataArr[];
   StringToCharArray(postData, postDataArr);
   ResetLastError();
//Print("array data "+CharArrayToString(postDataArr));
// Send WebRequest
   uchar result[];
   string resultHeaders;


   int res = WebRequest("POST", url, headers, 5000, postDataArr, result, resultHeaders);
   if(res == -1)
     {
      int error = GetLastError();
      PrintFormat("WebRequest failed. Error code: %d - %s", error, ErrorDescription(error));
     }
   else
     {
      Print("Data sent successfully. Server response: ", CharArrayToString(result));
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

//+------------------------------------------------------------------+
