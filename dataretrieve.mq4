//+------------------------------------------------------------------+
//|                                                    DataRetriever |
//|                                                      Amicobot.it |
//|                                             https://amicobot.it  |
//+------------------------------------------------------------------+
#property copyright "Eduardo Meli"
#property link      "https://amicobot.it"
#property version   "1.01"
#property strict

// Global variables
datetime startTime;          // Time when the EA starts running
string sessionID;            // Session ID for the EA instance
input string apiKey = "abc";
const string url = "https://amicobot.it/receive-data"; // Your WordPress endpoint
input string name = "test";
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Initialize variables
   startTime = TimeCurrent();
   sessionID = GetSessionID();

// Check if URL is allowed
   if(!IsUrlAllowed(url))
     {
      Print("Error: The URL is not listed in the allowed URLs. Please add it in Tools > Options > Expert Advisors.");
      return(INIT_FAILED);
     }
   Print("Succesfully started");
   SendAccountData();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Perform any cleanup if necessary
  }
  
 /* 
bool test = true;
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime lastSendTime = 0;
   datetime currentTime = TimeCurrent();

   if(test)
     {
      SendAccountData(); // fire the send function once and then sleep indefintely
      test=false;
     }

   // Send data every 60 seconds
   if(currentTime - lastSendTime >= 60)
   {

      lastSendTime = currentTime;

   }

  }*/

//+------------------------------------------------------------------+
//| Function to send account data                                    |
//+------------------------------------------------------------------+
void SendAccountData()
  {
  Print("Attempting to send");
   if(name == "")
     {
      Alert("No name has been specified. Aborting");
      return;
     }
// Collect account data
   long account_id = AccountInfoInteger(ACCOUNT_LOGIN);
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);

// Calculate daily and monthly profit
   double dailyProfit = CalculateProfitForPeriod(PERIOD_D1);
   double monthlyProfit = CalculateProfitForPeriod(PERIOD_MN1);
   int running_days = GetRunningDays();
   double gain = CalculateGain();
   double win_rate = CalculateWinRate();

// Prepare data to send
   string postData = "name=" + name +
                     "&account_id=" + IntegerToString(account_id)+
                     "&session_id=" + sessionID +
                     "&profit=" + DoubleToString(profit, 2) +
                     "&daily=" + DoubleToString(dailyProfit, 2) +
                     "&monthly=" + DoubleToString(monthlyProfit, 2) +
                     "&running_days=" + IntegerToString(running_days)+
                     "&gain=" + DoubleToString(gain, 2) +
                     "&win_rate=" + DoubleToString(win_rate, 2);

// Include API key in headers
   const string headers = "API-Key: " + urlencode(apiKey) + "\r\n" +
                          "Content-Type: application/x-www-form-urlencoded\r\n";

   ResetLastError();

// Send WebRequest
   char resultData[];
   string resultHeaders;
   char postDataArr[];
   StringToCharArray(postData, postDataArr);

   int res = WebRequest("POST", url, headers, 0, postDataArr, resultData, resultHeaders);

   if(res == -1)
     {
      int error = GetLastError();
      Print("WebRequest failed. Error code: ", error);
      if(error == 4016)
        {
         Print("Possible cause: URL not listed in allowed URLs.");
        }
      Print(postData);
     }
   else
     {
      Print("Data sent successfully. Server response: ", CharArrayToString(resultData));
     }
  }

//+------------------------------------------------------------------+
//| Function to generate or retrieve a session ID                    |
//+------------------------------------------------------------------+
string GetSessionID()
  {
   return("MT4");
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
int GetRunningDays()
  {
   int days = (int)((TimeCurrent() - startTime) / 86400);
   return(days);
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
//| Function to get the initial balance when the EA started          |
//+------------------------------------------------------------------+
double GetInitialBalance()
  {
// For simplicity, we'll assume the initial balance is the balance when the EA started
// Alternatively, you can store the initial balance in a global variable or file
   static double initialBalance = AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_PROFIT);
   return(initialBalance);
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
         if(OrderType() == OP_BUY || OrderType() == OP_SELL) // Only count buy/sell orders
           {
            totalTrades++;
            if(OrderProfit() > 0)
               winningTrades++;
           }
        }
     }
   if(totalTrades == 0)
      return(0.0);
   return(((double)winningTrades / totalTrades) * 100.0);
  }

//+------------------------------------------------------------------+
//| Function to check if the URL is allowed in WebRequest settings   |
//+------------------------------------------------------------------+
bool IsUrlAllowed(string checkUrl)
  {
//string urls = TerminalInfoString(TERMINAL_WEBREQUEST_URLS);
//if(StringFind(urls, checkUrl) != -1)
//   return(true);
//else
//   return(false);
   return true;
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

