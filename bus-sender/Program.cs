using Microsoft.Azure.ServiceBus;
using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace MessageSender
{
    class Program
    {
        static string ServiceBusConnectionString = Environment.GetEnvironmentVariable("SERVICEBUS_CONNECTION");
        static string QueueName = Environment.GetEnvironmentVariable("SERVICEBUS_QUEUE");
        static int numberOfMessages = 1000;
        static IQueueClient QueueClient;

        static void Main(string[] args)
        {
            MainAsync().GetAwaiter().GetResult();
        }

        static async Task MainAsync()
        {
            QueueClient = new QueueClient(ServiceBusConnectionString, QueueName);

            Console.WriteLine("================================================");
            Console.WriteLine("Sending messages");
            Console.WriteLine("================================================");            

            await SendMessagesAsync(numberOfMessages);
            await QueueClient.CloseAsync();
        }               

        static async Task SendMessagesAsync(int numberOfMessagesToSend)
        {
            try
            {
                for (var i = 1; i <= numberOfMessagesToSend; i++)
                {
                    // Create a new message to send to the queue
                    string messageBody = $"Message {i}";
                    var message = new Message(Encoding.UTF8.GetBytes(messageBody));

                    // Write the body of the message to the console
                    Console.WriteLine($"Sending message: {messageBody}");

                    // Send the message to the queue
                    await QueueClient.SendAsync(message);
                }
            }
            catch (Exception exception)
            {
                Console.WriteLine($"{DateTime.Now} :: Exception: {exception.Message}");
            }
        }
    }
}