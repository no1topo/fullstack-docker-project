package main

import (
	"fmt"
	"os"
	"server/common"
	"server/router"
)

// Start server
func main() {
	port := common.FallbackString(os.Getenv("PORT"), "8080")
	if err := router.Router().Run(":" + port); err != nil {
		fmt.Println("server error:", err)
	}
}
