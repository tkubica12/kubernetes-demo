package com.microsoft.azuresample.acscicdtodo.Utils;

import org.springframework.stereotype.Component;
import java.sql.DriverManager;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Component
public class SqlHelper {
    static final Logger LOG = LoggerFactory.getLogger(SqlHelper.class);

    public static String sqlurl;

    public static Connection GetConnection() throws SQLException {
        if(sqlurl==null){
            new SqlHelper().Init();
        }

        Connection connection = (Connection) DriverManager.getConnection(sqlurl);
        return connection;
    }

    public void Init(){
        Map<String, String> env = System.getenv();
        sqlurl = env.get("POSTGRESQL_URL");

        LOG.info("### INIT of SqlHelper called.");
    }
}
