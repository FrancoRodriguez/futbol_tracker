document.addEventListener("turbo:load", () => {
    const playerSelect = document.querySelector("#participation_player_id");
    const teamSelect = document.querySelector("#participation_team_id");
    const submitButton = document.querySelector("#submitParticipationButton");

    if (playerSelect && teamSelect && submitButton) {
        const toggleSubmitButton = () => {
            const isPlayerSelected = playerSelect.value !== "";
            const isTeamSelected = teamSelect.value !== "";
            submitButton.disabled = !(isPlayerSelected && isTeamSelected);
        };

        // Inicializa el estado del botón
        toggleSubmitButton();

        // Escucha los cambios en ambos campos
        playerSelect.addEventListener("change", toggleSubmitButton);
        teamSelect.addEventListener("change", toggleSubmitButton);
    }
});
